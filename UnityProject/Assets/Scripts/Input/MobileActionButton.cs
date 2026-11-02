using UnityEngine;
using UnityEngine.EventSystems;

namespace FreeFire3D.Input
{
    public sealed class MobileActionButton : MonoBehaviour, IPointerDownHandler, IPointerUpHandler, IPointerExitHandler
    {
        public enum ActionType
        {
            Fire,
            Aim,
            Sprint,
            Jump,
            Reload,
            Crouch,
            SwitchWeapon
        }

        [SerializeField] private MobileInputBridge inputBridge;
        [SerializeField] private ActionType action = ActionType.Fire;
        private int activePointer = int.MinValue;

        public void OnPointerDown(PointerEventData eventData)
        {
            if (activePointer != int.MinValue) return;
            activePointer = eventData.pointerId;
            SetHeld(true);
        }

        public void OnPointerUp(PointerEventData eventData)
        {
            if (eventData.pointerId != activePointer) return;
            SetHeld(false);
            activePointer = int.MinValue;
        }

        public void OnPointerExit(PointerEventData eventData)
        {
            if (eventData.pointerId != activePointer) return;
            SetHeld(false);
            activePointer = int.MinValue;
        }

        private void SetHeld(bool held)
        {
            if (inputBridge == null) return;

            switch (action)
            {
                case ActionType.Fire:
                    inputBridge.Fire(held);
                    break;
                case ActionType.Aim:
                    inputBridge.Aim(held);
                    break;
                case ActionType.Sprint:
                    inputBridge.Sprint(held);
                    break;
                case ActionType.Jump:
                    if (held) inputBridge.Jump();
                    break;
                case ActionType.Reload:
                    if (held) inputBridge.Reload();
                    break;
                case ActionType.Crouch:
                    if (held) inputBridge.Crouch();
                    break;
                case ActionType.SwitchWeapon:
                    if (held) inputBridge.SwitchWeapon();
                    break;
            }
        }

        private void OnDisable()
        {
            if (activePointer != int.MinValue)
                SetHeld(false);
            activePointer = int.MinValue;
        }
    }
}
