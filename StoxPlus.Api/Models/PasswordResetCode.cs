using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Server.Models
{
    public class PasswordResetCode
    {
        [Key]
        public int Id { get; set; }

        public int User_ID { get; set; }

        [Required]
        public string Code { get; set; } = string.Empty;

        public DateTime Expiration { get; set; }

        public bool IsUsed { get; set; } = false;

        // ✅ Explicitly map the foreign key
        [ForeignKey("User_ID")]
        public User? User { get; set; }
    }
}