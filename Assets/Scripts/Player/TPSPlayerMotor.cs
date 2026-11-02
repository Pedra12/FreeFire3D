using UnityEngine;

namespace FreeFire3D.Player
{
    [RequireComponent(typeof(CharacterController))]
    public sealed class TPSPlayerMotor : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private Transform cameraTransform;
        [SerializeField] private Animator animator;

        [Header("Movement")]
        [SerializeField, Min(0f)] private float walkSpeed = 3.8f;
        [SerializeField, Min(0f)] private float sprintSpeed = 5.8f;
        [SerializeField, Min(0f)] private float rotationSharpness = 14f;
        [SerializeField, Min(0f)] private float jumpHeight = 1.15f;
        [SerializeField] private float gravity = -22f;

        private CharacterController controller;
        private Vector2 moveInput;
        private float verticalVelocity;
        private bool sprintHeld;
        private bool jumpQueued;
        private bool grounded;

        public Vector3 HorizontalVelocity { get; private set; }

        private void Awake()
        {
            controller = GetComponent<CharacterController>();
            if (animator == null)
                animator = GetComponentInChildren<Animator>();
        }

        public void SetMoveInput(Vector2 value)
        {
            moveInput = Vector2.ClampMagnitude(value, 1f);
        }

        public void SetSprint(bool held)
        {
            sprintHeld = held;
        }

        public void QueueJump()
        {
            jumpQueued = true;
        }

        public void SetCamera(Transform value)
        {
            cameraTransform = value;
        }

        private void Update()
        {
            float deltaTime = Time.deltaTime;
            grounded = controller.isGrounded;

            if (grounded && verticalVelocity < 0f)
                verticalVelocity = -2f;

            if (jumpQueued && grounded)
                verticalVelocity = Mathf.Sqrt(jumpHeight * -2f * gravity);

            jumpQueued = false;
            verticalVelocity += gravity * deltaTime;

            Vector3 forward = cameraTransform != null
                ? Vector3.ProjectOnPlane(cameraTransform.forward, Vector3.up).normalized
                : Vector3.forward;
            Vector3 right = cameraTransform != null
                ? Vector3.ProjectOnPlane(cameraTransform.right, Vector3.up).normalized
                : Vector3.right;

            Vector3 moveDirection = forward * moveInput.y + right * moveInput.x;
            moveDirection = Vector3.ClampMagnitude(moveDirection, 1f);

            float targetSpeed = sprintHeld ? sprintSpeed : walkSpeed;
            HorizontalVelocity = moveDirection * targetSpeed;

            if (moveDirection.sqrMagnitude > 0.0001f)
            {
                Quaternion targetRotation = Quaternion.LookRotation(moveDirection, Vector3.up);
                transform.rotation = Quaternion.Slerp(
                    transform.rotation,
                    targetRotation,
                    1f - Mathf.Exp(-rotationSharpness * deltaTime));
            }

            Vector3 motion = HorizontalVelocity;
            motion.y = verticalVelocity;
            controller.Move(motion * deltaTime);

            if (animator != null)
            {
                animator.SetFloat("Speed", HorizontalVelocity.magnitude, 0.1f, deltaTime);
                animator.SetFloat("MoveX", moveInput.x, 0.1f, deltaTime);
                animator.SetFloat("MoveY", moveInput.y, 0.1f, deltaTime);
                animator.SetBool("Grounded", controller.isGrounded);
                animator.SetBool("Sprinting", sprintHeld && moveInput.sqrMagnitude > 0.01f);
            }
        }
    }
}
