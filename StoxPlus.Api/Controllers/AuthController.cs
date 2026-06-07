using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Server.Data;
using Server.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authorization;
using MailKit.Net.Smtp;
using MimeKit;
using System.Security.Cryptography;
using Server.Models.Requests;


namespace Server.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _config;

        public AuthController(AppDbContext context, IConfiguration config)
        {
            _context = context;
            _config = config;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterRequest request)
        {
            if (await _context.User.AnyAsync(u => u.Email == request.Email))
                return BadRequest("User already exists.");

            var user = new User
            {
                Business_Name = request.BusinessName,
                Business_Number = request.BusinessNumber,
                Email = request.Email,
                Phone_Number = request.Phone,
                Address = request.Address,
                Transit_Number = request.Transit,
                Password = BCrypt.Net.BCrypt.HashPassword(request.Password),
                DATE = DateTime.Now
            };

            _context.User.Add(user);
            await _context.SaveChangesAsync();

            var createdUser = await _context.User.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (createdUser == null)
                return StatusCode(500, "Failed to retrieve newly created user.");

            var defaultRole = await _context.Role.FirstOrDefaultAsync(r => r.Role_Name == "User");
            if (defaultRole == null)
                return StatusCode(500, "Default role 'User' not found.");

            _context.UserRole.Add(new UserRole
            {
                User_ID = createdUser.User_ID,
                Role_ID = defaultRole.Role_ID
            });

            _context.UserActivityLogs.Add(new UserActivityLog
            {
                UserId = createdUser.User_ID,
                Action = "Registered",
                Timestamp = DateTime.UtcNow
            });

            await _context.SaveChangesAsync();

            var role = await _context.UserRole
                .Include(ur => ur.Role)
                .Where(ur => ur.User_ID == createdUser.User_ID)
                .Select(ur => ur.Role.Role_Name)
                .FirstOrDefaultAsync();

            var token = GenerateJwtToken(createdUser, role);
            var refreshToken = GenerateRefreshToken(createdUser.User_ID);

            _context.RefreshTokens.Add(refreshToken);
            await _context.SaveChangesAsync();

            return Ok(new { token, refreshToken = refreshToken.Token, role });
        }

        [HttpPost("google-login")]
        public async Task<IActionResult> GoogleLogin([FromBody] GoogleLoginRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.IdToken))
                return BadRequest("Google ID token is required.");

            Google.Apis.Auth.GoogleJsonWebSignature.Payload payload;
            try
            {
                var settings = new Google.Apis.Auth.GoogleJsonWebSignature.ValidationSettings
                {
                    Audience = new[] { _config["GoogleAuth:WebClientId"] }
                };
                payload = await Google.Apis.Auth.GoogleJsonWebSignature
                    .ValidateAsync(request.IdToken, settings);
            }
            catch (Exception ex)
            {
                return Unauthorized($"Invalid Google token: {ex.Message}");
            }

            if (string.IsNullOrWhiteSpace(payload.Email))
                return BadRequest("Google account has no email.");

            var user = await _context.User.FirstOrDefaultAsync(u => u.Email == payload.Email);
            bool isNewUser = false;

            if (user == null)
            {
                user = new User
                {
                    Business_Name = payload.Name ?? payload.Email,
                    Business_Number = "",
                    Email = payload.Email,
                    Phone_Number = "",
                    Address = "",
                    Transit_Number = "",
                    Password = BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString()),
                    DATE = DateTime.Now
                };
                _context.User.Add(user);
                await _context.SaveChangesAsync();

                var defaultRole = await _context.Role.FirstOrDefaultAsync(r => r.Role_Name == "User");
                if (defaultRole == null)
                    return StatusCode(500, "Default role 'User' not found.");

                _context.UserRole.Add(new UserRole
                {
                    User_ID = user.User_ID,
                    Role_ID = defaultRole.Role_ID
                });

                _context.UserActivityLogs.Add(new UserActivityLog
                {
                    UserId = user.User_ID,
                    Action = "Registered (Google)",
                    Timestamp = DateTime.UtcNow
                });

                await _context.SaveChangesAsync();
                isNewUser = true;
            }

            var role = await _context.UserRole
                .Include(ur => ur.Role)
                .Where(ur => ur.User_ID == user.User_ID)
                .Select(ur => ur.Role.Role_Name)
                .FirstOrDefaultAsync();

            if (string.IsNullOrEmpty(role))
            {
                var defaultRole = await _context.Role.FirstOrDefaultAsync(r => r.Role_Name == "User");
                if (defaultRole != null)
                {
                    _context.UserRole.Add(new UserRole
                    {
                        User_ID = user.User_ID,
                        Role_ID = defaultRole.Role_ID
                    });
                    await _context.SaveChangesAsync();
                    role = defaultRole.Role_Name;
                }
                else
                {
                    role = "User";
                }
            }

            if (!isNewUser)
            {
                _context.UserActivityLogs.Add(new UserActivityLog
                {
                    UserId = user.User_ID,
                    Action = "Logged in (Google)",
                    Timestamp = DateTime.UtcNow
                });
            }

            var token = GenerateJwtToken(user, role);
            var refreshToken = GenerateRefreshToken(user.User_ID);

            _context.RefreshTokens.Add(refreshToken);
            await _context.SaveChangesAsync();

            return Ok(new { token, refreshToken = refreshToken.Token, role, isNewUser });
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            var user = await _context.User.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user == null || !BCrypt.Net.BCrypt.Verify(request.Password, user.Password))
                return Unauthorized("Invalid email or password.");

            var role = await _context.UserRole
                .Include(ur => ur.Role)
                .Where(ur => ur.User_ID == user.User_ID)
                .Select(ur => ur.Role.Role_Name)
                .FirstOrDefaultAsync();

            _context.UserActivityLogs.Add(new UserActivityLog
            {
                UserId = user.User_ID,
                Action = "Logged in",
                Timestamp = DateTime.UtcNow
            });

            var token = GenerateJwtToken(user, role);
            var refreshToken = GenerateRefreshToken(user.User_ID);

            _context.RefreshTokens.Add(refreshToken);
            await _context.SaveChangesAsync();

            return Ok(new { token, refreshToken = refreshToken.Token, role });
        }

        [HttpPost("refresh-token")]
        public async Task<IActionResult> RefreshToken([FromBody] Server.Models.Requests.RefreshTokenRequest request)
        {
            var refreshToken = request.RefreshToken;
        
            if (string.IsNullOrEmpty(refreshToken))
                return BadRequest("The refreshToken field is required.");
        
            var tokenInDb = await _context.RefreshTokens
                .Include(r => r.User)
                .FirstOrDefaultAsync(r => r.Token == refreshToken
                    && r.Expires > DateTime.UtcNow
                    && !r.IsRevoked);
        
            if (tokenInDb == null)
                return Unauthorized("Invalid or expired refresh token.");
        
            var role = await _context.UserRole
                .Include(ur => ur.Role)
                .Where(ur => ur.User_ID == tokenInDb.User_ID)
                .Select(ur => ur.Role.Role_Name)
                .FirstOrDefaultAsync();
        
            tokenInDb.IsRevoked = true;
            var newRefreshToken = GenerateRefreshToken(tokenInDb.User_ID);
            _context.RefreshTokens.Add(newRefreshToken);
        
            var newAccessToken = GenerateJwtToken(tokenInDb.User, role);
            await _context.SaveChangesAsync();
        
            return Ok(new { token = newAccessToken, refreshToken = newRefreshToken.Token });
        }

        [HttpPost("logout")]
        [Authorize]
        public async Task<IActionResult> Logout()
        {
            var userIdClaim = User.FindFirst("userId")?.Value;
            if (string.IsNullOrEmpty(userIdClaim))
                return Unauthorized("User ID not found.");

            int userId = int.Parse(userIdClaim);

            _context.UserActivityLogs.Add(new UserActivityLog
            {
                UserId = userId,
                Action = "Logged out",
                Timestamp = DateTime.UtcNow
            });

            var activeTokens = await _context.RefreshTokens
                .Where(t => t.User_ID == userId && !t.IsRevoked && t.Expires > DateTime.UtcNow)
                .ToListAsync();

            foreach (var token in activeTokens)
                token.IsRevoked = true;

            await _context.SaveChangesAsync();
            return Ok("Logout logged and tokens revoked.");
        }

        [HttpPost("check-email")]
        public async Task<IActionResult> CheckEmail([FromBody] EmailCheckRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Email))
                return BadRequest("Email is required.");

            var exists = await _context.User.AnyAsync(u => u.Email == request.Email);
            return Ok(new { exists });
        }

        // ✅ UPDATED: Sends 6-digit code instead of link
        [HttpPost("forgot-password")]
        public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Email))
                return BadRequest("Email is required.");

            var user = await _context.User.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user == null)
                return Ok("If this email exists, a reset code has been sent.");

            // Generate 6-digit code
            var code = new Random().Next(100000, 999999).ToString();

            // Invalidate old unused codes
            var oldCodes = _context.PasswordResetCodes
                .Where(c => c.User_ID == user.User_ID && !c.IsUsed);
            _context.PasswordResetCodes.RemoveRange(oldCodes);

            _context.PasswordResetCodes.Add(new PasswordResetCode
            {
                User_ID = user.User_ID,
                Code = code,
                Expiration = DateTime.UtcNow.AddMinutes(10),
                IsUsed = false
            });

            await _context.SaveChangesAsync();

            // Send email with code
            var message = new MimeMessage();
            message.From.Add(MailboxAddress.Parse(_config["EmailSettings:SenderEmail"]));
            message.To.Add(MailboxAddress.Parse(user.Email));
            message.Subject = "Your STOX Password Reset Code";
            message.Body = new TextPart("html")
            {
                Text = $@"
                    <div style='font-family: Arial, sans-serif; max-width: 420px; margin: 0 auto;'>
                        <h2 style='color: #1B2D4F;'>STOX Password Reset</h2>
                        <p style='color: #6B7280;'>Your password reset code is:</p>
                        <div style='background: #EEF2F7; padding: 24px; text-align: center;
                                    border-radius: 12px; margin: 20px 0;'>
                            <h1 style='color: #1B2D4F; letter-spacing: 10px;
                                       font-size: 40px; margin: 0;'>{code}</h1>
                        </div>
                        <p style='color: #9BA5B4; font-size: 13px;'>
                            This code expires in <strong>10 minutes</strong>.
                            Do not share it with anyone.
                        </p>
                    </div>"
            };

            using var smtp = new SmtpClient();
            await smtp.ConnectAsync(
                _config["EmailSettings:SmtpServer"],
                int.Parse(_config["EmailSettings:Port"]),
                true);
            await smtp.AuthenticateAsync(
                _config["EmailSettings:SenderEmail"],
                _config["EmailSettings:SenderPassword"]);
            await smtp.SendAsync(message);
            await smtp.DisconnectAsync(true);

            return Ok("Reset code sent to your email.");
        }

        // ✅ NEW: Verify 6-digit code
        [HttpPost("verify-reset-code")]
        public async Task<IActionResult> VerifyResetCode([FromBody] VerifyCodeRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Code))
                return BadRequest("Email and code are required.");

            var user = await _context.User.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user == null)
                return BadRequest("Invalid request.");

            var resetCode = await _context.PasswordResetCodes
                .FirstOrDefaultAsync(c =>
                    c.User_ID == user.User_ID &&
                    c.Code == request.Code &&
                    !c.IsUsed &&
                    c.Expiration > DateTime.UtcNow);

            if (resetCode == null)
                return BadRequest("Invalid or expired code.");

            return Ok(new { message = "Code verified.", email = request.Email });
        }

        // ✅ UPDATED: Reset password using email + code
        [HttpPost("reset-password")]
        public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordWithCodeRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.Email) ||
                string.IsNullOrWhiteSpace(request.Code) ||
                string.IsNullOrWhiteSpace(request.NewPassword))
                return BadRequest("All fields are required.");

            var user = await _context.User.FirstOrDefaultAsync(u => u.Email == request.Email);
            if (user == null)
                return BadRequest("Invalid request.");

            var resetCode = await _context.PasswordResetCodes
                .FirstOrDefaultAsync(c =>
                    c.User_ID == user.User_ID &&
                    c.Code == request.Code &&
                    !c.IsUsed &&
                    c.Expiration > DateTime.UtcNow);

            if (resetCode == null)
                return BadRequest("Invalid or expired code.");

            // Mark code as used and update password
            resetCode.IsUsed = true;
            user.Password = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);

            await _context.SaveChangesAsync();

            return Ok("Password reset successfully.");
        }

        private string GenerateJwtToken(User user, string role)
        {
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Key"]));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var token = new JwtSecurityToken(
                issuer: _config["Jwt:Issuer"],
                audience: _config["Jwt:Audience"],
                claims: new[]
                {
                    new Claim(JwtRegisteredClaimNames.Sub, user.Email),
                    new Claim("userId", user.User_ID.ToString()),
                    new Claim(ClaimTypes.Role, role)
                },
                expires: DateTime.Now.AddHours(1),
                signingCredentials: creds);

            return new JwtSecurityTokenHandler().WriteToken(token);
        }

        private RefreshToken GenerateRefreshToken(int userId)
        {
            return new RefreshToken
            {
                Token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64)),
                Expires = DateTime.UtcNow.AddDays(7),
                IsRevoked = false,
                User_ID = userId
            };
        }
    }

    // Keep these at bottom of AuthController.cs
    public class RegisterRequest
    {
        public string BusinessName { get; set; } = string.Empty;
        public string BusinessNumber { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Phone { get; set; } = string.Empty;
        public string Address { get; set; } = string.Empty;
        public string Transit { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }
    
    public class LoginRequest
    {
        public string Email { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
    }
    
}