using UnityEngine;

namespace FreeFire3D.EditorTools
{
    /// <summary>
    /// Entry point configured in Unity Build Automation > Advanced Settings > Pre-Export.
    /// </summary>
    public static class UnityBuildAutomationHooks
    {
#if UNITY_CLOUD_BUILD
        public static void PreExport()
        {
            Debug.Log("FreeFire3D: preparing validated Android scene for Unity Build Automation.");
            AndroidCiBuilder.PrepareForUnityBuildAutomation();
        }
#endif
    }
}
