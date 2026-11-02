using System;
using System.Linq;
using UnityEditor;
using UnityEngine;

namespace FreeFire3D.EditorTools
{
    public sealed class OliviaModelPostprocessor : AssetPostprocessor
    {
        private const string OliviaAssetPath = "Assets/Game/Characters/Olivia/Olivia.fbx";

        private void OnPreprocessModel()
        {
            if (!string.Equals(assetPath, OliviaAssetPath, StringComparison.OrdinalIgnoreCase))
                return;

            var importer = (ModelImporter)assetImporter;
            importer.animationType = ModelImporterAnimationType.Human;
            importer.avatarSetup = ModelImporterAvatarSetup.CreateFromThisModel;
            importer.importAnimation = false;
            importer.optimizeGameObjects = false;
            importer.meshCompression = ModelImporterMeshCompression.Off;
            importer.isReadable = false;
            importer.importCameras = false;
            importer.importLights = false;
            importer.importNormals = ModelImporterNormals.Import;
            importer.importTangents = ModelImporterTangents.CalculateMikk;
        }

        private static void OnPostprocessAllAssets(
            string[] importedAssets,
            string[] deletedAssets,
            string[] movedAssets,
            string[] movedFromAssetPaths)
        {
            if (!importedAssets.Contains(OliviaAssetPath, StringComparer.OrdinalIgnoreCase))
                return;

            EditorApplication.delayCall += ValidateOliviaAvatar;
        }

        [MenuItem("FreeFire3D/Validate Olivia Humanoid Avatar")]
        private static void ValidateOliviaAvatar()
        {
            var assets = AssetDatabase.LoadAllAssetsAtPath(OliviaAssetPath);
            var avatar = assets.OfType<Avatar>().FirstOrDefault();

            if (avatar == null)
            {
                Debug.LogError("Olivia FBX imported without an Avatar sub-asset.");
                return;
            }

            if (!avatar.isValid || !avatar.isHuman)
            {
                Debug.LogError("Olivia Avatar is invalid or not Humanoid. Check the Rig tab and bone mapping.");
                return;
            }

            Debug.Log("Olivia Humanoid Avatar validated successfully.");
        }
    }
}
