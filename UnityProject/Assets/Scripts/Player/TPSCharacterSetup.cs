using UnityEngine;
using FreeFire3D.CameraSystem;

namespace FreeFire3D.Player
{
    [DisallowMultipleComponent]
    public sealed class TPSCharacterSetup : MonoBehaviour
    {
        [SerializeField] private TPSPlayerMotor motor;
        [SerializeField] private TPSCameraRig cameraRig;

        private void Awake()
        {
            if (motor == null)
                motor = GetComponent<TPSPlayerMotor>();

            if (cameraRig != null)
            {
                cameraRig.SetTarget(transform);
                if (motor != null)
                    motor.SetCamera(cameraRig.CameraTransform);
            }
        }

        private void OnValidate()
        {
            if (motor == null)
                motor = GetComponent<TPSPlayerMotor>();
        }
    }
}
