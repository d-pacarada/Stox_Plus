using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Server.Data;
using Server.Models;
using System.Security.Claims;

namespace Server.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class SettingsController : ControllerBase
    {
        private readonly AppDbContext _context;

        public SettingsController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet("profile")]
        public async Task<IActionResult> GetProfile()
        {
            var userIdString = User.FindFirst("userId")?.Value;
            if (string.IsNullOrEmpty(userIdString))
                return Unauthorized();

            int userId = int.Parse(userIdString);
            var user = await _context.User.FindAsync(userId);
            if (user == null) return NotFound();

            return Ok(new {
                user.Business_Name,
                user.Business_Number,
                user.Email,
                user.Phone_Number,
                user.Address,
                user.Transit_Number,
            });
        }

        [HttpPut("update-details")]
        public async Task<IActionResult> UpdateDetails([FromBody] UpdateDetailsRequest request)
        {
            var userId = int.Parse(User.FindFirst("userId")?.Value ?? "0");

            var user = await _context.User.FindAsync(userId);
            if (user == null)
                return NotFound("User not found.");

            // Only update if value is provided
            if (!string.IsNullOrWhiteSpace(request.Address))
                user.Address = request.Address;

            if (!string.IsNullOrWhiteSpace(request.PhoneNumber))
                user.Phone_Number = request.PhoneNumber;

            if (!string.IsNullOrWhiteSpace(request.TransitNumber))
                user.Transit_Number = request.TransitNumber;

            // ✅ Fixed: was 'dto.BusinessNumber', now 'request.BusinessNumber'
            if (!string.IsNullOrWhiteSpace(request.BusinessNumber))
                user.Business_Number = request.BusinessNumber;

            _context.UserActivityLogs.Add(new UserActivityLog
            {
                UserId = userId,
                Action = "Updated Info",
                Timestamp = DateTime.UtcNow
            });

            await _context.SaveChangesAsync();

            return Ok("Details updated successfully.");
        }

        [HttpPut("update-password")]
        public async Task<IActionResult> UpdatePassword([FromBody] UpdatePasswordRequest request)
        {
            var userId = int.Parse(User.FindFirst("userId")?.Value ?? "0");

            var user = await _context.User.FindAsync(userId);
            if (user == null)
                return NotFound("User not found.");

            if (!BCrypt.Net.BCrypt.Verify(request.CurrentPassword, user.Password))
                return BadRequest("Current password is incorrect.");

            user.Password = BCrypt.Net.BCrypt.HashPassword(request.NewPassword);
            await _context.SaveChangesAsync();

            return Ok("Password updated successfully.");
        }
    }

    // DTOs
    public class UpdateDetailsRequest
    {
        public string? Address { get; set; }
        public string? PhoneNumber { get; set; }
        public string? TransitNumber { get; set; }
        public string? BusinessNumber { get; set; } // ✅ added
    }

    public class UpdatePasswordRequest
    {
        public string CurrentPassword { get; set; } = string.Empty;
        public string NewPassword { get; set; } = string.Empty;
    }
}