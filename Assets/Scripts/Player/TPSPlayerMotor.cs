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
        [SerializeField, Min(0f)] private float crouchSpeed = 2.0f;
        [SerializeField, Min(0f)] private float rotationSharpness = 14f;
        [SerializeField, Min(0f)] private float jumpHeight = 1.15f;
        [SerializeField] private float gravity = -22f;

        [Header("Crouch")]
        [SerializeField, Min(0.5f)] private float crouchHeight = 1.15f;

        private CharacterController controller;
        private Vector2 moveInput;
        private float verticalVelocity;
        private float standingHeight;
        private Vector3 standingCenter;
        private bool sprintHeld;
        private bool jumpQueued;

        public Vector3 HorizontalVelocity { get; private set; }
        public bool IsCrouched { get; private set; }

        private void Awake()
        {
            controller = GetComponent<CharacterController>();
            standingHeight = controller.height;
            standingCenter = controller.center;

            if (animator == null)
                animator = GetComponentInChildren<Animator>();
        }

        public void SetMoveInput(Vector2 value)
        {
            moveInput = Vector2.ClampMagnitude(value, 1f);
        }

        public void SetSprint(bool held)
        {
            sprintHeld = held && !IsCrouched;
        }

        public void QueueJump()
        {
            if (IsCrouched)
                SetCrouched(false);

            jumpQueued = true;
        }

        public void SetCamera(Transform value)
        {
            cameraTransform = value;
        }

        public void ToggleCrouch()
        {
            SetCrouched(!IsCrouched);
        }

        public bool SetCrouched(bool crouched)
        {
            if (controller == null)
                return false;

            if (crouched == IsCrouched)
                return true;

            if (!crouched && !CanStandUp())
                return false;

            IsCrouched = crouched;
            sprintHeld = false;

            float nextHeight = crouched
                ? Mathf.Clamp(crouchHeight, controller.radius * 2f, standingHeight)
                : standingHeight;

            controller.height = nextHeight;
            controller.center = crouched
                ? new Vector3(standingCenter.x,
                    standingCenter.y - (standingHeight - nextHeight) * 0.5f,
                    standingCenter.z)
                : standingCenter;

            return true;
        }

        private bool CanStandUp()
        {
            float radius = controller.radius * 0.95f;
            Vector3 bottom = transform.position + transform.rotation *
                (controller.center - Vector3.up * (controller.height * 0.5f - radius));
            Vector3 top = bottom + Vector3.up * Mathf.Max(0f, standingHeight - radius * 2f);

            Collider[] overlaps = Physics.OverlapCapsule(
                bottom, top, radius, ~0, QueryTriggerInteraction.Ignore);

            foreach (Collider overlap in overlaps)
            {
                if (overlap == controller || overlap.transform == transform ||
                    overlap.transform.IsChildOf(transform))
                    continue;

                return false;
            }

            return true;
        }

        private void Update()
        {
            float deltaTime = Time.deltaTime;
            bool grounded = controller.isGrounded;

            if (grounded && verticalVelocity < 0f)
                verticalVelocity = -2f;

            if (jumpQueued && grounded && !IsCrouched)
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

            float targetSpeed = IsCrouched
                ? crouchSpeed
                : sprintHeld ? sprintSpeed : walkSpeed;

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
                animator.SetBool("Crouching", IsCrouched);
            }
        }
    }
}
