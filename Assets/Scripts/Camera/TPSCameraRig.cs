using UnityEngine;

namespace FreeFire3D.CameraSystem
{
    public sealed class TPSCameraRig : MonoBehaviour
    {
        [Header("Target")]
        [SerializeField] private Transform target;
        [SerializeField] private Vector3 targetOffset = new Vector3(0f, 1.55f, 0f);

        [Header("Orbit")]
        [SerializeField] private float distance = 3.6f;
        [SerializeField] private float lookSensitivity = 0.12f;
        [SerializeField] private float minPitch = -28f;
        [SerializeField] private float maxPitch = 68f;
        [SerializeField] private float followSharpness = 18f;

        [Header("Collision")]
        [SerializeField] private float collisionRadius = 0.22f;
        [SerializeField] private LayerMask collisionMask = ~0;

        private float yaw;
        private float pitch = 12f;
        private Vector2 pendingLook;
        private static readonly RaycastHit[] collisionHits = new RaycastHit[16];

        public Transform CameraTransform => transform;

        public void SetTarget(Transform value)
        {
            target = value;
        }

        public void AddLookDelta(Vector2 delta)
        {
            pendingLook += delta;
        }

        private void LateUpdate()
        {
            if (target == null)
                return;

            yaw += pendingLook.x * lookSensitivity;
            pitch = Mathf.Clamp(pitch - pendingLook.y * lookSensitivity, minPitch, maxPitch);
            pendingLook = Vector2.zero;

            Quaternion orbitRotation = Quaternion.Euler(pitch, yaw, 0f);
            Vector3 focusPoint = target.position + targetOffset;
            Vector3 desiredPosition = focusPoint - orbitRotation * Vector3.forward * distance;

            Vector3 castDirection = desiredPosition - focusPoint;
            float castDistance = castDirection.magnitude;
            if (castDistance > 0.001f)
            {
                int hitCount = Physics.SphereCastNonAlloc(
                    focusPoint, collisionRadius, castDirection.normalized,
                    collisionHits, castDistance, collisionMask, QueryTriggerInteraction.Ignore);

                float nearestDistance = castDistance;
                bool foundObstacle = false;

                for (int i = 0; i < hitCount; i++)
                {
                    Transform hitTransform = collisionHits[i].transform;
                    if (hitTransform == null ||
                        hitTransform == target ||
                        hitTransform.IsChildOf(target))
                        continue;

                    if (collisionHits[i].distance < nearestDistance)
                    {
                        nearestDistance = collisionHits[i].distance;
                        foundObstacle = true;
                    }
                }

                if (foundObstacle)
                {
                    desiredPosition = focusPoint + castDirection.normalized *
                        Mathf.Max(0.15f, nearestDistance - collisionRadius);
                }
            }

            float blend = 1f - Mathf.Exp(-followSharpness * Time.deltaTime);
            transform.position = Vector3.Lerp(transform.position, desiredPosition, blend);
            transform.rotation = Quaternion.Slerp(transform.rotation, orbitRotation, blend);
        }
    }
}
