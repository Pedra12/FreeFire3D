using System;
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace FreeFire3D.EditorTools
{
    public sealed class OliviaAvatarAssetBuilder : AssetPostprocessor
    {
        private const string ModelPath = "Assets/Game/Characters/Olivia/Olivia.glb";
        private const string AvatarPath = "Assets/Game/Characters/Olivia/OliviaAvatar.asset";

        private static readonly (string HumanName, string TransformName)[] BoneMap =
        {
            ("Hips", "Hips"),
            ("Spine", "Spine"),
            ("Chest", "Chest"),
            ("Neck", "Neck"),
            ("Head", "Head"),
            ("LeftShoulder", "LeftShoulder"),
            ("LeftUpperArm", "LeftUpperArm"),
            ("LeftLowerArm", "LeftLowerArm"),
            ("LeftHand", "LeftHand"),
            ("RightShoulder", "RightShoulder"),
            ("RightUpperArm", "RightUpperArm"),
            ("RightLowerArm", "RightLowerArm"),
            ("RightHand", "RightHand"),
            ("LeftUpperLeg", "LeftUpperLeg"),
            ("LeftLowerLeg", "LeftLowerLeg"),
            ("LeftFoot", "LeftFoot"),
            ("RightUpperLeg", "RightUpperLeg"),
            ("RightLowerLeg", "RightLowerLeg"),
            ("RightFoot", "RightFoot")
        };

        private static void OnPostprocessAllAssets(
            string[] importedAssets,
            string[] deletedAssets,
            string[] movedAssets,
            string[] movedFromAssetPaths)
        {
            if (importedAssets.Contains(ModelPath, StringComparer.OrdinalIgnoreCase))
                EditorApplication.delayCall += BuildAvatar;
        }

        [MenuItem("FreeFire3D/Build Olivia Humanoid Avatar")]
        private static void BuildAvatar()
        {
            GameObject modelAsset = AssetDatabase.LoadAssetAtPath<GameObject>(ModelPath);
            if (modelAsset == null)
            {
                modelAsset = AssetDatabase.LoadAllAssetsAtPath(ModelPath)
                    .OfType<GameObject>()
                    .FirstOrDefault(candidate => candidate.transform.parent == null)
                    ?? AssetDatabase.LoadAllAssetsAtPath(ModelPath).OfType<GameObject>().FirstOrDefault();
            }

            if (modelAsset == null)
            {
                Debug.LogError("Olivia GLB has not been imported as a GameObject. Check the glTFast importer.");
                return;
            }

            GameObject instance = PrefabUtility.InstantiatePrefab(modelAsset) as GameObject;
            if (instance == null)
                instance = UnityEngine.Object.Instantiate(modelAsset);

            instance.name = "Olivia_AvatarBuildRoot";
            try
            {
                Transform[] transforms = instance.GetComponentsInChildren<Transform>(true);
                var byName = transforms
                    .GroupBy(transform => transform.name)
                    .ToDictionary(group => group.Key, group => group.First());

                string[] missing = BoneMap
                    .Where(mapping => !byName.ContainsKey(mapping.TransformName))
                    .Select(mapping => mapping.TransformName)
                    .ToArray();

                if (missing.Length > 0)
                {
                    Debug.LogError("Olivia GLB is missing required humanoid transforms: " + string.Join(", ", missing));
                    return;
                }

                HumanBone[] human = BoneMap.Select(mapping => new HumanBone
                {
                    humanName = mapping.HumanName,
                    boneName = mapping.TransformName,
                    limit = new HumanLimit { useDefaultValues = true }
                }).ToArray();

                SkeletonBone[] skeleton = transforms.Select(transform => new SkeletonBone
                {
                    name = transform.name,
                    position = transform.localPosition,
                    rotation = transform.localRotation,
                    scale = transform.localScale
                }).ToArray();

                HumanDescription description = new HumanDescription
                {
                    human = human,
                    skeleton = skeleton,
                    armStretch = 0.05f,
                    legStretch = 0.05f,
                    upperArmTwist = 0.5f,
                    lowerArmTwist = 0.5f,
                    upperLegTwist = 0.5f,
                    lowerLegTwist = 0.5f,
                    feetSpacing = 0f,
                    hasTranslationDoF = false
                };

                Avatar avatar = AvatarBuilder.BuildHumanAvatar(instance, description);
                if (avatar == null || !avatar.isValid || !avatar.isHuman)
                {
                    if (avatar != null)
                        UnityEngine.Object.DestroyImmediate(avatar);
                    Debug.LogError("Unity could not validate Olivia as a Humanoid Avatar. The skeleton mapping or bind pose needs correction.");
                    return;
                }

                avatar.name = "Olivia_Humanoid_Avatar";
                if (AssetDatabase.LoadAssetAtPath<Avatar>(AvatarPath) != null)
                    AssetDatabase.DeleteAsset(AvatarPath);

                AssetDatabase.CreateAsset(avatar, AvatarPath);
                AssetDatabase.SaveAssets();

                if (!AssetDatabase.Contains(avatar))
                    Debug.LogError("Olivia Avatar was valid in memory but could not be saved as an asset.");
                else
                    Debug.Log("Olivia Humanoid Avatar built and saved successfully.");
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(instance);
            }
        }
    }
}
