using UnityEngine;
using UnityEngine.EventSystems;

namespace FreeFire3D.Input
{
    public sealed class VirtualJoystick : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
    {
        [SerializeField] private RectTransform baseRect;
        [SerializeField] private RectTransform handleRect;
        [SerializeField, Range(0.2f, 1f)] private float handleRange = 0.72f;
        [SerializeField] private MobileInputBridge inputBridge;

        private Vector2 output;

        private void Awake()
        {
            if (baseRect == null) baseRect = transform as RectTransform;
            ResetStick();
        }

        public void OnPointerDown(PointerEventData eventData) => UpdateStick(eventData);
        public void OnDrag(PointerEventData eventData) => UpdateStick(eventData);

        public void OnPointerUp(PointerEventData eventData)
        {
            output = Vector2.zero;
            if (inputBridge != null) inputBridge.Move(output);
            if (handleRect != null) handleRect.anchoredPosition = Vector2.zero;
        }

        private void UpdateStick(PointerEventData eventData)
        {
            if (baseRect == null || handleRect == null) return;
            if (!RectTransformUtility.ScreenPointToLocalPointInRectangle(
                baseRect, eventData.position, eventData.pressEventCamera, out Vector2 localPoint))
                return;

            Vector2 halfSize = baseRect.rect.size * 0.5f;
            Vector2 normalized = new Vector2(
                halfSize.x > 0f ? localPoint.x / halfSize.x : 0f,
                halfSize.y > 0f ? localPoint.y / halfSize.y : 0f);
            output = Vector2.ClampMagnitude(normalized, 1f);
            handleRect.anchoredPosition = new Vector2(output.x * halfSize.x, output.y * halfSize.y) * handleRange;
            if (inputBridge != null) inputBridge.Move(output);
        }

        private void OnDisable()
        {
            output = Vector2.zero;
            if (inputBridge != null) inputBridge.Move(output);
            if (handleRect != null) handleRect.anchoredPosition = Vector2.zero;
        }

        private void ResetStick()
        {
            if (handleRect != null) handleRect.anchoredPosition = Vector2.zero;
        }
    }
}
