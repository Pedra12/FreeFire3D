using UnityEngine;

namespace FreeFire3D.Match
{
    [DisallowMultipleComponent]
    public sealed class MatchRuntimeSettings : MonoBehaviour
    {
        [SerializeField, Range(30, 60)] private int targetFrameRate = 60;

        private void Awake()
        {
            Screen.orientation = ScreenOrientation.LandscapeLeft;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            Input.multiTouchEnabled = true;
            QualitySettings.vSyncCount = 0;
            Application.targetFrameRate = targetFrameRate;
        }
    }
}
