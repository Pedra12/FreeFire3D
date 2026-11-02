using UnityEngine;
using UnityEngine.EventSystems;
using FreeFire3D.CameraSystem;

namespace FreeFire3D.Input
{
    public sealed class TouchLookArea : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
    {
        [SerializeField] private TPSCameraRig cameraRig;
        [SerializeField] private bool ignoreFirstDragDelta = true;
        private int activePointer = int.MinValue;
        private bool firstDrag = true;

        public void OnPointerDown(PointerEventData eventData)
        {
            if (activePointer != int.MinValue) return;
            activePointer = eventData.pointerId;
            firstDrag = ignoreFirstDragDelta;
        }

        public void OnDrag(PointerEventData eventData)
        {
            if (eventData.pointerId != activePointer || cameraRig == null) return;
            if (firstDrag)
            {
                firstDrag = false;
                return;
            }
            cameraRig.AddLookDelta(eventData.delta);
        }

        public void OnPointerUp(PointerEventData eventData)
        {
            if (eventData.pointerId == activePointer)
                activePointer = int.MinValue;
        }

        private void OnDisable()
        {
            activePointer = int.MinValue;
            firstDrag = true;
        }
    }
}
