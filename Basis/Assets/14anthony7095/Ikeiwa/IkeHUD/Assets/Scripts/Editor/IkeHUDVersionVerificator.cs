using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using UnityEditor.PackageManager;
using UnityEditor.PackageManager.Requests;
using System.Linq;

namespace Ikeiwa.NeoHUD
{
    [InitializeOnLoad]
    public static class IkeHUDVersionVerificator
    {
        public static int version = 2;

        private static bool require2022 = true;
        private static bool ignoreIfCCK = true;
        private static List<PackageRequirement> packageRequirements = new List<PackageRequirement>()
        {
            new PackageRequirement
            {
                packageName = "com.vrchat.avatars",
                version = "3.7.0",
                missingError = new VersionError { message = "Could not find VRChat SDK 3.0, please verify if it's installed.", buttonText = "Fix", buttonURL = "https://creators.vrchat.com/sdk/" },
                versionError = new VersionError { message = "You are using an incompatible version of the SDK, please update it.", buttonText = "Fix", buttonURL = "https://creators.vrchat.com/sdk/updating-the-sdk" }
            },
            new PackageRequirement
            {
                packageName = "com.vrcfury.vrcfury",
                version = "1.858.0",
                missingError = new VersionError { message = "Could not find VRCFury, please verify if it's installed.", buttonText = "Fix", buttonURL = "https://vrcfury.com/download" },
                versionError = new VersionError { message = "You are using an incompatible version of VRCFury, please update it.", buttonText = "Fix", buttonURL = "https://vrcfury.com/download" }
            },
            new PackageRequirement
            {
                packageName = "dev.vrlabs.final-ik-stub",
                version = "Any",
                missingError = new VersionError { message = "Could not find FinalIK or FinalIK Stub, please verify if it's installed.", buttonText = "Fix", buttonURL = "https://vrlabs.dev/packages?package=dev.vrlabs.final-ik-stub" },
                versionError = new VersionError { message = "You are using an incompatible version of FinalIK Stub, please update it.", buttonText = "Fix", buttonURL = "https://vrlabs.dev/packages?package=dev.vrlabs.final-ik-stub" },
                classesEquivalent = new string[] { "GrounderIK", "LimbIK" }
            }
        };

        public class VersionError
        {
            public string message;
            public string buttonText;
            public string buttonURL;
        }

        private class PackageRequirement
        {
            public string packageName;
            public string version;
            public VersionError missingError;
            public VersionError versionError;
            public string[] classesEquivalent = null;
        }

        static ListRequest Request;
        static bool hasChecked;
        static int hasPinged;
        static Object objectToPing;
        public const string ignorePrefName = "IkeHUDDontShowAgain";

        static IkeHUDVersionVerificator()
        {
            if (EditorPrefs.HasKey(PlayerSettings.productName + "-" + ignorePrefName + "-" + version))
                return;

            Request = Client.List(true);
            EditorApplication.update += Progress;
        }

        static void Progress()
        {
            if (Request.IsCompleted && !hasChecked)
            {
                hasChecked = true;

                if (Request.Status >= StatusCode.Failure)
                    Debug.Log(Request.Error.message);

                CheckInstall();
            }

            if(hasPinged < 10 && objectToPing) 
            {
                hasPinged++;

                if(hasPinged >= 10)
                    EditorApplication.update -= Progress; 

                Selection.activeObject = objectToPing;
                EditorGUIUtility.PingObject(Selection.activeObject);
            }
        }

        static private void CheckInstall()
        {
            List<VersionError> errors = new List<VersionError>();

#if CVR_CCK_EXISTS
            if (ignoreIfCCK)
            {
                PingAssets();
                return;
            }
#endif

#if !UNITY_2022
        if(require2022)
            errors.Add(new VersionError { message="You are using the wrong unity version, you need at least Unity 2022.3.6", buttonText = "Fix", buttonURL = "https://creators.vrchat.com/sdk/upgrade/unity-2022" });
#else // !VRC_SDK_VRCSDK3

#if !VRC_SDK_VRCSDK3
        errors.Add(new VersionError { message = "Could not find VRChat SDK 3.0, please verify if it's installed.", buttonText = "Fix", buttonURL = "https://creators.vrchat.com/sdk/" });
#else // UNITY_2022
            if (Request != null && Request.Result != null)
            {
                foreach (var requirement in packageRequirements) 
                {
                    var package = Request.Result.FirstOrDefault(p => p.name == requirement.packageName);

                    bool hasEquivalent = true;
                    if(requirement.classesEquivalent == null)
                        hasEquivalent = false;
                    else
                    {
                        foreach (var eqClass in requirement.classesEquivalent)
                        {
                            if(AssetDatabase.FindAssets("t:script " + eqClass).Length == 0)
                            {
                                hasEquivalent = false;
                                break;
                            }
                        }
                    }

                    if (!hasEquivalent)
                    {
                        if (package == null)
                            errors.Add(requirement.missingError);
                        else if (!CompareVersions(package.version, requirement.version))
                            errors.Add(requirement.versionError);
                    }
                }
            }
#endif // !VRC_SDK_VRCSDK3

#endif // UNITY_2022

            if (errors.Count > 0)
                IkeHUDVersionVerificatorWindow.DisplayError(errors);
            else
            {
                PingAssets();
            }
        }

        static private bool CompareVersions(string installed, string required)
        {
            if(required == "Any")
                return true;

            System.Version installedVersion = null;
            System.Version requiredVersion = null;

            try
            {
                installedVersion = new System.Version(installed);
                requiredVersion = new System.Version(required);
            }
            catch(System.Exception ex)
            {
                return false;
            }
            

            return installedVersion >= requiredVersion;
        }

        static private void PingAssets()
        {
            var assetPings = AssetDatabase.FindAssets($"t: {typeof(IkeHUDAssetPing).Name}").ToList()
                    .Select(AssetDatabase.GUIDToAssetPath)
                    .Select(AssetDatabase.LoadMainAssetAtPath).ToList();

            if (assetPings.Count > 0)
            {
                foreach (IkeHUDAssetPing asset in assetPings)
                {
                    string prefName = PlayerSettings.productName + "-" + asset.name + "HasPinged";

#if CVR_CCK_EXISTS
                    if (!asset.isCVR)
                        continue;
#else
                    if (asset.isCVR)
                        continue;
#endif

                    if (asset.assetToPing && !EditorPrefs.GetBool(prefName, false))
                    {
                        objectToPing = asset.assetToPing;
                        EditorPrefs.SetBool(prefName, true);
                        break;
                    }
                }
            }
            else
                EditorApplication.update -= Progress;
        }
    }

    public class IkeHUDVersionVerificatorWindow : EditorWindow
    {
        private List<IkeHUDVersionVerificator.VersionError> errors;
        private Vector2 scroll;

        public static void DisplayError(List<IkeHUDVersionVerificator.VersionError> errors)
        {
            if (errors == null || errors.Count == 0)
                return;

            IkeHUDVersionVerificatorWindow window = GetWindow<IkeHUDVersionVerificatorWindow>(true, "IkeHUD Install Verificator");
            window.errors = errors;
            window.minSize = new Vector2(500, 40 * errors.Count + 30);
            window.maxSize = window.minSize;
        }

        void OnGUI()
        {
            if (errors == null || errors.Count == 0)
            {
                Close();
                return;
            }

            EditorGUILayout.BeginScrollView(scroll);

            foreach (var error in errors)
            {
                DrawIssueBox(error);
            }

            if(GUILayout.Button("Do not show again"))
            {
                EditorGUILayout.EndScrollView();
                EditorPrefs.SetBool(PlayerSettings.productName + "-" + IkeHUDVersionVerificator.ignorePrefName + "-" + IkeHUDVersionVerificator.version, true);
                Close();
                return;
            }

            EditorGUILayout.EndScrollView();
        }

        void DrawIssueBox(IkeHUDVersionVerificator.VersionError error)
        {
            if (error == null)
                return;

            bool haveButtons = !string.IsNullOrEmpty(error.buttonText);

            GUIStyle style = new GUIStyle("HelpBox");
            float width = haveButtons ? position.width - 110 : position.width - 20;
            if (haveButtons)
                style.fixedWidth = width;

            float minHeight = 40;

            EditorGUILayout.BeginHorizontal();

            GUIContent c = new GUIContent(error.message);
            float height = style.CalcHeight(c, width - 32);
            Rect rt = GUILayoutUtility.GetRect(c, style, GUILayout.MinHeight(Mathf.Max(minHeight, height)));
            EditorGUI.HelpBox(rt, error.message, MessageType.Error);

            if (haveButtons)
            {
                EditorGUILayout.BeginVertical();
                float buttonHeight = minHeight;

                if (GUILayout.Button(error.buttonText, GUILayout.Height(buttonHeight)))
                {
                    Application.OpenURL(error.buttonURL);
                    Repaint();
                }
                EditorGUILayout.EndVertical();
            }

            EditorGUILayout.EndHorizontal();
        }
    }
}