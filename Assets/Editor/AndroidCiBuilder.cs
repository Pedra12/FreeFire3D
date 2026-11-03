using System;
using System.IO;
using System.Linq;
using FreeFire3D.CameraSystem;
using FreeFire3D.Input;
using FreeFire3D.Match;
using FreeFire3D.Player;
using FreeFire3D.World;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.Animations;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.SceneManagement;

namespace FreeFire3D.EditorTools
{
    /// <summary>
    /// Deterministic CI entry point: import the approved assets, generate the first
    /// match scene when its prerequisites are ready, validate scene wiring, then build an APK.
    /// </summary>
    public static class AndroidCiBuilder
    {
        private const string MapPath = "Assets/Game/Maps/Clocktower/Clocktower.glb";
        private const string OliviaPath = "Assets/Game/Characters/Olivia/Olivia.glb";
        private const string AvatarPath = "Assets/Game/Characters/Olivia/OliviaAvatar.asset";
        private const string ControllerPath = "Assets/Game/Characters/Olivia/Olivia.controller";
        private const string ScenePath = "Assets/Scenes/Match.unity";
        private const string MatchConfigPath = "Assets/Game/Match/MatchConfiguration.asset";
        private const string OutputPath = "build/Android/FreeFire3D.apk";

        public static void Build()
        {
            Debug.Log("FreeFire3D Android CI: refreshing and importing approved assets.");
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);

            RequireAsset<GameObject>(MapPath, "Clocktower GLB");
            RequireAsset<GameObject>(OliviaPath, "Olivia GLB");

            Avatar avatar = AssetDatabase.LoadAssetAtPath<Avatar>(AvatarPath);
            if (avatar == null || !avatar.isValid || !avatar.isHuman)
                OliviaAvatarAssetBuilder.BuildAvatar();

            AnimatorController controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(ControllerPath);
            if (controller == null)
                QuaterniusAnimationImporter.BuildController();

            avatar = AssetDatabase.LoadAssetAtPath<Avatar>(AvatarPath);
            controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(ControllerPath);
            if (avatar == null || !avatar.isValid || !avatar.isHuman)
                throw new InvalidOperationException("Olivia Humanoid Avatar was not generated or is invalid.");
            if (controller == null)
                throw new InvalidOperationException("Quaternius Animator Controller was not generated.");

            InitialMatchSceneBuilder.BuildIfReady();
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);

            if (!File.Exists(ScenePath))
                throw new InvalidOperationException("Match.unity was not generated. Check the Unity import and scene-builder errors above.");

            ValidateAndPrepareScene();
            BuildAndroidApk();
        }

        private static T RequireAsset<T>(string path, string label) where T : UnityEngine.Object
        {
            T asset = AssetDatabase.LoadAssetAtPath<T>(path);
            if (asset == null)
                throw new InvalidOperationException(label + " is missing or failed to import: " + path);
            return asset;
        }

        private static void ValidateAndPrepareScene()
        {
            Scene scene = EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);
            GameObject[] roots = scene.GetRootGameObjects();

            T[] FindAll<T>() where T : Component =>
                roots.SelectMany(root => root.GetComponentsInChildren<T>(true)).ToArray();

            TPSPlayerMotor[] motors = FindAll<TPSPlayerMotor>();
            RequireCount(motors.Length, 1, "playable TPS player");
            TPSPlayerMotor motor = motors[0];

            CharacterController[] characterControllers = FindAll<CharacterController>();
            RequireCount(characterControllers.Length, 1, "player CharacterController");
            if (motor.GetComponent<CharacterController>() != characterControllers[0])
                throw new InvalidOperationException("CharacterController is not attached to the Olivia player root.");

            TPSCharacterSetup setup = motor.GetComponent<TPSCharacterSetup>();
            if (setup == null)
                throw new InvalidOperationException("Olivia is missing TPSCharacterSetup.");
            RequireReference(setup, "motor", motor);

            Animator[] animators = motor.GetComponentsInChildren<Animator>(true);
            RequireCount(animators.Length, 1, "Olivia Animator");
            Animator animator = animators[0];
            if (animator.avatar == null || !animator.avatar.isValid || !animator.avatar.isHuman)
                throw new InvalidOperationException("Olivia Animator does not have a valid Humanoid Avatar.");
            if (animator.runtimeAnimatorController == null)
                throw new InvalidOperationException("Olivia Animator has no runtime controller.");
            RequireReference(motor, "animator", animator);

            ClocktowerCollisionAuthoring[] maps = FindAll<ClocktowerCollisionAuthoring>();
            RequireCount(maps.Length, 1, "Clocktower map");
            MeshFilter[] mapMeshes = maps[0].GetComponentsInChildren<MeshFilter>(true)
                .Where(filter => filter.sharedMesh != null).ToArray();
            if (mapMeshes.Length == 0)
                throw new InvalidOperationException("Clocktower imported without any usable mesh geometry.");

            // Generate and serialize static collision before the APK is built.
            maps[0].BuildColliders();
            foreach (MeshFilter filter in mapMeshes)
            {
                MeshCollider collider = filter.GetComponent<MeshCollider>();
                if (collider == null || collider.sharedMesh != filter.sharedMesh || collider.convex)
                    throw new InvalidOperationException("Clocktower collision validation failed on " + filter.name + ".");
            }

            TPSCameraRig[] cameraRigs = FindAll<TPSCameraRig>();
            RequireCount(cameraRigs.Length, 1, "TPS camera rig");
            Camera[] cameras = FindAll<Camera>();
            RequireCount(cameras.Length, 1, "game camera");
            if (cameraRigs[0].gameObject != cameras[0].gameObject)
                throw new InvalidOperationException("TPSCameraRig and Camera must be on the same object.");
            RequireReference(setup, "cameraRig", cameraRigs[0]);

            MobileInputBridge[] bridges = FindAll<MobileInputBridge>();
            RequireCount(bridges.Length, 1, "mobile input bridge");
            RequireReference(bridges[0], "player", motor);
            RequireReference(bridges[0], "cameraRig", cameraRigs[0]);

            VirtualJoystick[] joysticks = FindAll<VirtualJoystick>();
            RequireCount(joysticks.Length, 1, "mobile movement joystick");
            RequireReference(joysticks[0], "inputBridge", bridges[0]);
            TouchLookArea[] lookAreas = FindAll<TouchLookArea>();
            RequireCount(lookAreas.Length, 1, "mobile camera-look area");
            RequireReference(lookAreas[0], "cameraRig", cameraRigs[0]);

            MobileActionButton[] actionButtons = FindAll<MobileActionButton>();
            if (actionButtons.Length < 7)
                throw new InvalidOperationException("Mobile HUD is missing one or more action buttons. Found: " + actionButtons.Length + ".");
            foreach (MobileActionButton actionButton in actionButtons)
                RequireReference(actionButton, "inputBridge", bridges[0]);

            RequireCount(FindAll<EventSystem>().Length, 1, "EventSystem");
            RequireCount(FindAll<MatchRuntimeSettings>().Length, 1, "match runtime settings");

            MatchConfiguration match = AssetDatabase.LoadAssetAtPath<MatchConfiguration>(MatchConfigPath);
            if (match == null || match.playersPerTeam != 4 || match.alliedBots != 3 ||
                match.enemyBots != 4 || match.playerCharacterId != "olivia" || !match.startDirectlyInMatch)
                throw new InvalidOperationException("The 4v4 offline match configuration is missing or inconsistent.");

            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(ScenePath, true)
            };

            EditorSceneManager.MarkSceneDirty(scene);
            if (!EditorSceneManager.SaveScene(scene))
                throw new InvalidOperationException("Unity could not save the validated Match scene.");

            Debug.Log(
                "UNITY_SCENE_VALIDATION_OK: one Olivia, one Clocktower, one TPS camera, " +
                mapMeshes.Length + " map meshes with colliders, and complete mobile HUD.");
        }

        private static void RequireCount(int actual, int expected, string label)
        {
            if (actual != expected)
                throw new InvalidOperationException(
                    "Expected exactly " + expected + " " + label + "(s), found " + actual + ".");
        }

        private static void RequireReference(
            UnityEngine.Object target,
            string propertyName,
            UnityEngine.Object expected)
        {
            SerializedObject serialized = new SerializedObject(target);
            SerializedProperty property = serialized.FindProperty(propertyName);
            if (property == null || property.objectReferenceValue != expected)
                throw new InvalidOperationException(
                    "Missing or incorrect serialized reference: " +
                    target.GetType().Name + "." + propertyName + ".");
        }

        private static void BuildAndroidApk()
        {
            if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.Android &&
                !EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android))
                throw new InvalidOperationException("Unity could not switch the active build target to Android.");

            EditorUserBuildSettings.buildAppBundle = false;
            PlayerSettings.companyName = "Pedra12";
            PlayerSettings.productName = "FreeFire3D";
            PlayerSettings.bundleVersion = "0.1.0";
            PlayerSettings.Android.bundleVersionCode = 1;
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.pedra12.freefire3d");
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;

            Directory.CreateDirectory(Path.GetDirectoryName(OutputPath));
            BuildPlayerOptions options = new BuildPlayerOptions
            {
                scenes = new[] { ScenePath },
                locationPathName = OutputPath,
                target = BuildTarget.Android,
                options = BuildOptions.None
            };

            BuildReport report = BuildPipeline.BuildPlayer(options);
            if (report.summary.result != BuildResult.Succeeded)
                throw new InvalidOperationException(
                    "Android build failed. Result: " + report.summary.result +
                    "; errors: " + report.summary.totalErrors +
                    "; warnings: " + report.summary.totalWarnings + ".");

            if (!File.Exists(OutputPath) || new FileInfo(OutputPath).Length == 0)
                throw new InvalidOperationException("Unity reported a successful build but the APK is missing or empty.");

            Debug.Log(
                "UNITY_ANDROID_BUILD_OK: " + OutputPath +
                "; size: " + new FileInfo(OutputPath).Length + " bytes.");
        }
    }
}
