using UnityEngine;

namespace FreeFire3D.World
{
    [DisallowMultipleComponent]
    public sealed class ClocktowerCollisionAuthoring : MonoBehaviour
    {
        [SerializeField] private bool buildOnAwake = true;
        [SerializeField] private bool markStatic = true;

        private void Awake()
        {
            if (buildOnAwake)
                BuildColliders();
        }

        [ContextMenu("Build Clocktower Mesh Colliders")]
        public void BuildColliders()
        {
            int created = 0;
            int refreshed = 0;

            foreach (MeshFilter filter in GetComponentsInChildren<MeshFilter>(true))
            {
                if (filter.sharedMesh == null)
                    continue;

                MeshCollider meshCollider = filter.GetComponent<MeshCollider>();
                if (meshCollider == null)
                {
                    meshCollider = filter.gameObject.AddComponent<MeshCollider>();
                    created++;
                }
                else
                {
                    refreshed++;
                }

                meshCollider.convex = false;
                meshCollider.isTrigger = false;
                meshCollider.sharedMesh = null;
                meshCollider.sharedMesh = filter.sharedMesh;

                if (markStatic)
                    filter.gameObject.isStatic = true;
            }

            Debug.Log($"Clocktower collision ready. New colliders: {created}; refreshed: {refreshed}.", this);
        }
    }
}
