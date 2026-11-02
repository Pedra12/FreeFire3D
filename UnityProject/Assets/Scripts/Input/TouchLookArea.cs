using UnityEngine;
using UnityEngine.EventSystems;
using FreeFire3D.CameraSystem;

namespace FreeFire3D.Input
{
    public sealed class TouchLookArea : MonoBehaviour, IPointerDownHandler, IDragHandler
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

        private void Update()
        {
            if (activePointer == int.MinValue) return;
            if (Input.touchCount == 0)
            {
                activePointer = int.MinValue;
                return;
            }

            for (int i = 0; i < Input.touchCount; i++)
            {
                Touch touch = Input.GetTouch(i);
                if (touch.fingerId == activePointer &&
                    (touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled))
                {
                    activePointer = int.MinValue;
                    return;
                }
            }
        }

        private void OnDisable()
        {
            activePointer = int.MinValue;
            firstDrag = true;
        }
    }
}
