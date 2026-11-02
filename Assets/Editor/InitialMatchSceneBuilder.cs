using System;
using System.IO;
using System.Linq;
using FreeFire3D.CameraSystem;
using FreeFire3D.Input;
using FreeFire3D.Match;
using FreeFire3D.Player;
using FreeFire3D.World;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace FreeFire3D.EditorTools
{
    public sealed class InitialMatchSceneBuilder : AssetPostprocessor
    {
        private const string MapPath = "Assets/Game/Maps/Clocktower/Clocktower.glb";
        private const string OliviaPath = "Assets/Game/Characters/Olivia/Olivia.glb";
        private const string AvatarPath = "Assets/Game/Characters/Olivia/OliviaAvatar.asset";
        private const string ScenePath = "Assets/Scenes/Match.unity";
        private const string MatchConfigPath = "Assets/Game/Match/MatchConfiguration.asset";
        private static bool building;

        private static void OnPostprocessAllAssets(
            string[] importedAssets,
            string[] deletedAssets,
            string[] movedAssets,
            string[] movedFromAssetPaths)
        {
            if (File.Exists(ScenePath) || building)
                return;

            if (File.Exists(MapPath) && File.Exists(OliviaPath) && File.Exists(AvatarPath))
                EditorApplication.delayCall += BuildIfReady;
        }

        [MenuItem("FreeFire3D/Build Initial Match Scene")]
        internal static void BuildIfReady()
        {
            if (building || File.Exists(ScenePath))
                return;

            building = true;
            try
            {
                GameObject mapAsset = LoadRootAsset(MapPath);
                GameObject oliviaAsset = LoadRootAsset(OliviaPath);
                Avatar avatar = AssetDatabase.LoadAssetAtPath<Avatar>(AvatarPath);

                if (mapAsset == null || oliviaAsset == null)
                {
                    Debug.LogWarning("Match scene is waiting for the Clocktower GLB and Olivia FBX importers.");
                    return;
                }

                if (avatar == null)
                {
                    Debug.LogError("Match scene was not created because Olivia has no valid Humanoid Avatar.");
                    return;
                }

                Directory.CreateDirectory("Assets/Scenes");
                Directory.CreateDirectory("Assets/Game/Match");

                Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                GameObject matchRoot = new GameObject("MatchRoot");
                matchRoot.AddComponent<MatchRuntimeSettings>();

                GameObject worldRoot = new GameObject("World");
                GameObject mapRoot = new GameObject("Clocktower");
                mapRoot.transform.SetParent(worldRoot.transform, false);
                GameObject mapInstance = InstantiateAsset(mapAsset, mapRoot.transform, "Clocktower_Model");
                mapRoot.AddComponent<ClocktowerCollisionAuthoring>();

                GameObject lightingRoot = new GameObject("Lighting");
                GameObject sun = new GameObject("Directional Light");
                sun.transform.SetParent(lightingRoot.transform, false);
                sun.transform.rotation = Quaternion.Euler(48f, -32f, 0f);
                Light directional = sun.AddComponent<Light>();
                directional.type = LightType.Directional;
                directional.intensity = 1.15f;
                directional.shadows = LightShadows.Soft;
                RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Skybox;
                RenderSettings.ambientIntensity = 1f;

                GameObject playerRoot = new GameObject("Player_Olivia");
                playerRoot.transform.position = Vector3.zero;
                CharacterController controller = playerRoot.AddComponent<CharacterController>();
                controller.height = 1.78f;
                controller.radius = 0.30f;
                controller.center = new Vector3(0f, 0.89f, 0f);
                controller.stepOffset = 0.30f;
                controller.slopeLimit = 48f;
                controller.skinWidth = 0.06f;
                controller.minMoveDistance = 0.001f;

                GameObject oliviaInstance = InstantiateAsset(oliviaAsset, playerRoot.transform, "Olivia_Model");
                oliviaInstance.transform.localPosition = Vector3.zero;
                oliviaInstance.transform.localRotation = Quaternion.identity;
                oliviaInstance.transform.localScale = Vector3.one;

                Animator animator = oliviaInstance.GetComponentInChildren<Animator>();
                if (animator == null)
                    animator = oliviaInstance.AddComponent<Animator>();
                animator.avatar = avatar;
                animator.applyRootMotion = false;
                animator.cullingMode = AnimatorCullingMode.CullUpdateTransforms;

                TPSPlayerMotor motor = playerRoot.AddComponent<TPSPlayerMotor>();
                TPSCharacterSetup characterSetup = playerRoot.AddComponent<TPSCharacterSetup>();

                GameObject cameraObject = new GameObject("Main Camera");
                cameraObject.tag = "MainCamera";
                cameraObject.transform.position = new Vector3(0f, 2.0f, -4.2f);
                cameraObject.transform.rotation = Quaternion.Euler(12f, 0f, 0f);
                Camera camera = cameraObject.AddComponent<Camera>();
                camera.fieldOfView = 65f;
                camera.nearClipPlane = 0.05f;
                camera.farClipPlane = 500f;
                cameraObject.AddComponent<AudioListener>();
                TPSCameraRig cameraRig = cameraObject.AddComponent<TPSCameraRig>();

                SetReference(motor, "animator", animator);
                SetReference(characterSetup, "motor", motor);
                SetReference(characterSetup, "cameraRig", cameraRig);

                CreateMatchConfiguration();

                GameObject eventSystemObject = new GameObject("EventSystem");
                eventSystemObject.AddComponent<EventSystem>();
                InputSystemUIInputModule inputModule = eventSystemObject.AddComponent<InputSystemUIInputModule>();
                inputModule.AssignDefaultActions();

                Canvas canvas = CreateCanvas();
                MobileInputBridge inputBridge = canvas.gameObject.AddComponent<MobileInputBridge>();
                SetReference(inputBridge, "player", motor);
                SetReference(inputBridge, "cameraRig", cameraRig);
                BuildHud(canvas, inputBridge, cameraRig);

                EditorSceneManager.SaveScene(scene, ScenePath);
                EditorBuildSettings.scenes = new[]
                {
                    new EditorBuildSettingsScene(ScenePath, true)
                };
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();

                Debug.Log("Initial Match scene created with one Clocktower map, one Olivia player and mobile movement HUD.");
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
            }
            finally
            {
                building = false;
            }
        }

        private static GameObject LoadRootAsset(string path)
        {
            GameObject root = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (root != null)
                return root;

            return AssetDatabase.LoadAllAssetsAtPath(path)
                .OfType<GameObject>()
                .FirstOrDefault(candidate => candidate.transform.parent == null)
                ?? AssetDatabase.LoadAllAssetsAtPath(path).OfType<GameObject>().FirstOrDefault();
        }

        private static GameObject InstantiateAsset(GameObject asset, Transform parent, string instanceName)
        {
            GameObject instance = PrefabUtility.InstantiatePrefab(asset) as GameObject;
            if (instance == null)
                instance = UnityEngine.Object.Instantiate(asset);

            instance.name = instanceName;
            instance.transform.SetParent(parent, false);
            return instance;
        }

        private static Canvas CreateCanvas()
        {
            GameObject canvasObject = new GameObject(
                "MobileHUD",
                typeof(RectTransform),
                typeof(Canvas),
                typeof(CanvasScaler),
                typeof(GraphicRaycaster));

            Canvas canvas = canvasObject.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 20;

            CanvasScaler scaler = canvasObject.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1920f, 1080f);
            scaler.matchWidthOrHeight = 0.5f;
            return canvas;
        }

        private static void BuildHud(Canvas canvas, MobileInputBridge bridge, TPSCameraRig cameraRig)
        {
            Sprite background = AssetDatabase.GetBuiltinExtraResource<Sprite>("UI/Skin/UISprite.psd");
            Sprite knob = AssetDatabase.GetBuiltinExtraResource<Sprite>("UI/Skin/Knob.psd");

            Image lookImage = CreateImage(
                "CameraLookArea", canvas.transform, background,
                new Vector2(0.5f, 0f), Vector2.one, Vector2.zero, Vector2.zero,
                new Color(1f, 1f, 1f, 0.002f));
            lookImage.transform.SetAsFirstSibling();
            TouchLookArea lookArea = lookImage.gameObject.AddComponent<TouchLookArea>();
            SetReference(lookArea, "cameraRig", cameraRig);

            Image joystickBase = CreateImage(
                "MovementJoystick", canvas.transform, background,
                Vector2.zero, Vector2.zero, new Vector2(155f, 160f), new Vector2(230f, 230f),
                new Color(0.08f, 0.11f, 0.15f, 0.55f));
            Image joystickHandle = CreateImage(
                "JoystickHandle", joystickBase.transform, knob,
                new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), Vector2.zero, new Vector2(88f, 88f),
                new Color(0.86f, 0.9f, 0.95f, 0.82f));

            VirtualJoystick joystick = joystickBase.gameObject.AddComponent<VirtualJoystick>();
            SetReference(joystick, "baseRect", joystickBase.rectTransform);
            SetReference(joystick, "handleRect", joystickHandle.rectTransform);
            SetReference(joystick, "inputBridge", bridge);

            CreateActionButton(canvas.transform, background, bridge, MobileActionButton.ActionType.Fire,
                "ATIRAR", new Vector2(1f, 0f), new Vector2(-150f, 165f), new Vector2(142f, 142f));
            CreateActionButton(canvas.transform, background, bridge, MobileActionButton.ActionType.Aim,
                "MIRA", new Vector2(1f, 0f), new Vector2(-320f, 165f), new Vector2(104f, 104f));
            CreateActionButton(canvas.transform, background, bridge, MobileActionButton.ActionType.Jump,
                "PULAR", new Vector2(1f, 0f), new Vector2(-155f, 340f), new Vector2(104f, 104f));
            CreateActionButton(canvas.transform, background, bridge, MobileActionButton.ActionType.Crouch,
                "AGACHAR", new Vector2(1f, 0f), new Vector2(-155f, 30f), new Vector2(96f, 96f));
            CreateActionButton(canvas.transform, background, bridge, MobileActionButton.ActionType.Reload,
                "RECARREGAR", new Vector2(1f, 0f), new Vector2(-320f, 330f), new Vector2(96f, 96f));
            CreateActionButton(canvas.transform, background, bridge, MobileActionButton.ActionType.SwitchWeapon,
                "ARMA", new Vector2(1f, 0f), new Vector2(-320f, 30f), new Vector2(96f, 96f));
            CreateActionButton(canvas.transform, background, bridge, MobileActionButton.ActionType.Sprint,
                "CORRER", Vector2.zero, new Vector2(330f, 150f), new Vector2(104f, 104f));
        }

        private static Image CreateImage(
            string objectName,
            Transform parent,
            Sprite sprite,
            Vector2 anchorMin,
            Vector2 anchorMax,
            Vector2 anchoredPosition,
            Vector2 size,
            Color color)
        {
            GameObject imageObject = new GameObject(objectName, typeof(RectTransform), typeof(CanvasRenderer), typeof(Image));
            imageObject.transform.SetParent(parent, false);
            RectTransform rect = imageObject.GetComponent<RectTransform>();
            rect.anchorMin = anchorMin;
            rect.anchorMax = anchorMax;
            rect.anchoredPosition = anchoredPosition;
            rect.sizeDelta = size;

            Image image = imageObject.GetComponent<Image>();
            image.sprite = sprite;
            image.color = color;
            image.raycastTarget = true;
            return image;
        }

        private static void CreateActionButton(
            Transform parent,
            Sprite sprite,
            MobileInputBridge bridge,
            MobileActionButton.ActionType action,
            string label,
            Vector2 anchor,
            Vector2 position,
            Vector2 size)
        {
            Image image = CreateImage(
                "HUD_" + action, parent, sprite,
                anchor, anchor, position, size,
                new Color(0.08f, 0.11f, 0.15f, action == MobileActionButton.ActionType.Fire ? 0.82f : 0.62f));

            MobileActionButton actionButton = image.gameObject.AddComponent<MobileActionButton>();
            SetReference(actionButton, "inputBridge", bridge);
            SetEnum(actionButton, "action", (int)action);

            Font font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            if (font == null)
                return;

            GameObject labelObject = new GameObject("Label", typeof(RectTransform), typeof(CanvasRenderer), typeof(Text));
            labelObject.transform.SetParent(image.transform, false);
            RectTransform labelRect = labelObject.GetComponent<RectTransform>();
            labelRect.anchorMin = Vector2.zero;
            labelRect.anchorMax = Vector2.one;
            labelRect.offsetMin = Vector2.zero;
            labelRect.offsetMax = Vector2.zero;

            Text text = labelObject.GetComponent<Text>();
            text.font = font;
            text.text = label;
            text.fontSize = action == MobileActionButton.ActionType.Fire ? 24 : 18;
            text.fontStyle = FontStyle.Bold;
            text.alignment = TextAnchor.MiddleCenter;
            text.color = Color.white;
            text.raycastTarget = false;
        }

        private static void CreateMatchConfiguration()
        {
            if (AssetDatabase.LoadAssetAtPath<MatchConfiguration>(MatchConfigPath) != null)
                return;

            MatchConfiguration configuration = ScriptableObject.CreateInstance<MatchConfiguration>();
            configuration.playersPerTeam = 4;
            configuration.alliedBots = 3;
            configuration.enemyBots = 4;
            configuration.playerCharacterId = "olivia";
            configuration.startDirectlyInMatch = true;
            AssetDatabase.CreateAsset(configuration, MatchConfigPath);
        }

        private static void SetReference(Object target, string propertyName, Object value)
        {
            SerializedObject serialized = new SerializedObject(target);
            SerializedProperty property = serialized.FindProperty(propertyName);
            if (property == null)
                throw new InvalidOperationException($"Serialized field not found: {target.GetType().Name}.{propertyName}");
            property.objectReferenceValue = value;
            serialized.ApplyModifiedPropertiesWithoutUndo();
        }

        private static void SetEnum(Object target, string propertyName, int value)
        {
            SerializedObject serialized = new SerializedObject(target);
            SerializedProperty property = serialized.FindProperty(propertyName);
            if (property == null)
                throw new InvalidOperationException($"Serialized field not found: {target.GetType().Name}.{propertyName}");
            property.enumValueIndex = value;
            serialized.ApplyModifiedPropertiesWithoutUndo();
        }
    }
}
