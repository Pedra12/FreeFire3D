using System;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

namespace FreeFire3D.EditorTools
{
    public sealed class QuaterniusAnimationImporter : AssetPostprocessor
    {
        private const string AnimationPath = "Assets/Game/Animations/Quaternius/UAL1_Standard.fbx";
        private const string ControllerPath = "Assets/Game/Characters/Olivia/Olivia.controller";

        private void OnPreprocessModel()
        {
            if (!string.Equals(assetPath, AnimationPath, StringComparison.OrdinalIgnoreCase))
                return;

            ModelImporter importer = (ModelImporter)assetImporter;
            importer.importAnimation = true;
            importer.animationType = ModelImporterAnimationType.Human;
            importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
            importer.materialImportMode = ModelImporterMaterialImportMode.None;
            importer.importCameras = false;
            importer.importLights = false;
            importer.optimizeGameObjects = false;
            importer.animationCompression = ModelImporterAnimationCompression.Optimal;
            importer.resampleCurves = true;
        }

        private void OnPostprocessModel(GameObject root)
        {
            if (!string.Equals(assetPath, AnimationPath, StringComparison.OrdinalIgnoreCase))
                return;

            // Keep the donor skeleton and animation curves, but strip its renderers so
            // the animation pack cannot become a second playable character in the scene.
            foreach (Renderer renderer in root.GetComponentsInChildren<Renderer>(true))
                UnityEngine.Object.DestroyImmediate(renderer);

            foreach (MeshFilter filter in root.GetComponentsInChildren<MeshFilter>(true))
                UnityEngine.Object.DestroyImmediate(filter);
        }

        private static void OnPostprocessAllAssets(
            string[] importedAssets,
            string[] deletedAssets,
            string[] movedAssets,
            string[] movedFromAssetPaths)
        {
            if (importedAssets.Contains(AnimationPath, StringComparer.OrdinalIgnoreCase))
                EditorApplication.delayCall += BuildController;
        }

        [MenuItem("FreeFire3D/Build Olivia Animation Controller")]
        private static void BuildController()
        {
            AnimationClip[] clips = AssetDatabase.LoadAllAssetsAtPath(AnimationPath)
                .OfType<AnimationClip>()
                .Where(clip => clip != null && !clip.name.StartsWith("__", StringComparison.Ordinal))
                .ToArray();

            Avatar sourceAvatar = AssetDatabase.LoadAllAssetsAtPath(AnimationPath)
                .OfType<Avatar>()
                .FirstOrDefault(avatar => avatar != null && avatar.isValid && avatar.isHuman);

            if (sourceAvatar == null)
            {
                Debug.LogError("Quaternius FBX did not produce a valid Humanoid Avatar. Check its Rig import settings.");
                return;
            }

            if (clips.Length < 20)
            {
                Debug.LogError($"Quaternius FBX imported only {clips.Length} clips; expected at least 20.");
                return;
            }

            AnimationClip FindClip(string requested)
            {
                AnimationClip match = clips.FirstOrDefault(clip =>
                    string.Equals(clip.name, requested, StringComparison.OrdinalIgnoreCase));
                if (match != null)
                    return match;

                return clips.FirstOrDefault(clip =>
                    clip.name.EndsWith(requested, StringComparison.OrdinalIgnoreCase));
            }

            AnimationClip idle = FindClip("Idle_Loop");
            AnimationClip walk = FindClip("Walk_Loop");
            AnimationClip jog = FindClip("Jog_Fwd_Loop");
            AnimationClip sprint = FindClip("Sprint_Loop");
            AnimationClip crouchIdle = FindClip("Crouch_Idle_Loop");
            AnimationClip crouchWalk = FindClip("Crouch_Fwd_Loop");
            AnimationClip jumpStart = FindClip("Jump_Start");
            AnimationClip jumpLoop = FindClip("Jump_Loop");
            AnimationClip jumpLand = FindClip("Jump_Land");

            var required = new[]
            {
                idle, walk, jog, sprint, crouchIdle, crouchWalk,
                jumpStart, jumpLoop, jumpLand
            };
            if (required.Any(clip => clip == null))
            {
                Debug.LogError(
                    "Quaternius FBX is missing one or more required locomotion clips: " +
                    string.Join(", ", new[]
                    {
                        "Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop",
                        "Crouch_Idle_Loop", "Crouch_Fwd_Loop",
                        "Jump_Start", "Jump_Loop", "Jump_Land"
                    }.Where((name, index) => required[index] == null)));
                return;
            }

            if (AssetDatabase.LoadAssetAtPath<AnimatorController>(ControllerPath) != null)
                AssetDatabase.DeleteAsset(ControllerPath);

            AnimatorController controller =
                AnimatorController.CreateAnimatorControllerAtPath(ControllerPath);
            controller.AddParameter("Speed", AnimatorControllerParameterType.Float);
            controller.AddParameter("Crouching", AnimatorControllerParameterType.Bool);
            controller.AddParameter("Grounded", AnimatorControllerParameterType.Bool);

            AnimatorStateMachine stateMachine = controller.layers[0].stateMachine;
            AnimatorState locomotionState = stateMachine.AddState("Locomotion");
            stateMachine.defaultState = locomotionState;

            BlendTree locomotion = new BlendTree
            {
                name = "Olivia_Locomotion",
                blendType = BlendTreeType.Simple1D,
                blendParameter = "Speed",
                useAutomaticThresholds = false
            };
            AssetDatabase.AddObjectToAsset(locomotion, ControllerPath);
            locomotion.AddChild(idle, 0f);
            locomotion.AddChild(walk, 3.8f);
            locomotion.AddChild(jog, 4.6f);
            locomotion.AddChild(sprint, 5.8f);
            locomotionState.motion = locomotion;

            AnimatorState crouchState = stateMachine.AddState("Crouch");
            BlendTree crouch = new BlendTree
            {
                name = "Olivia_Crouch",
                blendType = BlendTreeType.Simple1D,
                blendParameter = "Speed",
                useAutomaticThresholds = false
            };
            AssetDatabase.AddObjectToAsset(crouch, ControllerPath);
            crouch.AddChild(crouchIdle, 0f);
            crouch.AddChild(crouchWalk, 2f);
            crouchState.motion = crouch;

            AnimatorState jumpStartState = stateMachine.AddState("Jump_Start", jumpStart);
            AnimatorState jumpLoopState = stateMachine.AddState("Jump_Loop", jumpLoop);
            AnimatorState jumpLandState = stateMachine.AddState("Jump_Land", jumpLand);

            AnimatorStateTransition toCrouch = locomotionState.AddTransition(crouchState);
            toCrouch.hasExitTime = false;
            toCrouch.duration = 0.12f;
            toCrouch.AddCondition(AnimatorConditionMode.If, 0f, "Crouching");

            AnimatorStateTransition fromCrouch = crouchState.AddTransition(locomotionState);
            fromCrouch.hasExitTime = false;
            fromCrouch.duration = 0.12f;
            fromCrouch.AddCondition(AnimatorConditionMode.IfNot, 0f, "Crouching");

            AnimatorStateTransition startToLoop = jumpStartState.AddTransition(jumpLoopState);
            startToLoop.hasExitTime = true;
            startToLoop.exitTime = 0.85f;
            startToLoop.duration = 0.08f;

            AnimatorStateTransition loopToLand = jumpLoopState.AddTransition(jumpLandState);
            loopToLand.hasExitTime = false;
            loopToLand.duration = 0.08f;
            loopToLand.AddCondition(AnimatorConditionMode.If, 0f, "Grounded");

            AnimatorStateTransition landToMove = jumpLandState.AddTransition(locomotionState);
            landToMove.hasExitTime = true;
            landToMove.exitTime = 0.9f;
            landToMove.duration = 0.12f;

            AnimatorStateTransition anyToJump = stateMachine.AddAnyStateTransition(jumpStartState);
            anyToJump.hasExitTime = false;
            anyToJump.duration = 0.08f;
            anyToJump.canTransitionToSelf = false;
            anyToJump.AddCondition(AnimatorConditionMode.IfNot, 0f, "Grounded");

            EditorUtility.SetDirty(controller);
            AssetDatabase.SaveAssets();

            Debug.Log(
                $"Olivia Humanoid animation controller built. " +
                $"Source Avatar: {sourceAvatar.name}; clips: {clips.Length}; " +
                $"locomotion, crouch and jump states configured.");

            InitialMatchSceneBuilder.BuildIfReady();
        }
    }
}
