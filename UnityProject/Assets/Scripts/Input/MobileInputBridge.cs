using UnityEngine;
using FreeFire3D.Player;
using FreeFire3D.CameraSystem;

namespace FreeFire3D.Input
{
    public sealed class MobileInputBridge : MonoBehaviour
    {
        [SerializeField] private TPSPlayerMotor player;
        [SerializeField] private TPSCameraRig cameraRig;

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
    }
}
