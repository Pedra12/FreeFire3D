using UnityEngine;
using UnityEngine.Events;
using FreeFire3D.Player;
using FreeFire3D.CameraSystem;

namespace FreeFire3D.Input
{
    public sealed class MobileInputBridge : MonoBehaviour
    {
        [Header("Core references")]
        [SerializeField] private TPSPlayerMotor player;
        [SerializeField] private TPSCameraRig cameraRig;

        [Header("Gameplay events (connect after weapon/combat systems exist)")]
        [SerializeField] private UnityEvent aimPressed;
        [SerializeField] private UnityEvent aimReleased;
        [SerializeField] private UnityEvent firePressed;
        [SerializeField] private UnityEvent fireReleased;
        [SerializeField] private UnityEvent reloadPressed;
        [SerializeField] private UnityEvent crouchPressed;
        [SerializeField] private UnityEvent weaponSwitchPressed;

        public void Move(Vector2 value)
        {
            if (player != null) player.SetMoveInput(value);
        }

        public void Look(Vector2 delta)
        {
            if (cameraRig != null) cameraRig.AddLookDelta(delta);
        }

        public void Sprint(bool held)
        {
            if (player != null) player.SetSprint(held);
        }

        public void Jump()
        {
            if (player != null) player.QueueJump();
        }

        public void Aim(bool held)
        {
            if (held) aimPressed?.Invoke();
            else aimReleased?.Invoke();
        }

        public void Fire(bool held)
        {
            if (held) firePressed?.Invoke();
            else fireReleased?.Invoke();
        }

        public void Reload()
        {
            reloadPressed?.Invoke();
        }

        public void Crouch()
        {
            crouchPressed?.Invoke();
        }

        public void SwitchWeapon()
        {
            weaponSwitchPressed?.Invoke();
        }
    }
}
