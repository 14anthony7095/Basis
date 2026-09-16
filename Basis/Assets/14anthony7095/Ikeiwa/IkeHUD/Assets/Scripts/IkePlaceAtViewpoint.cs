using UnityEngine;
using UnityEngine.Animations;

#if VRC_SDK_VRCSDK3
using VRC.SDK3.Avatars.Components;
#endif

#if CVR_CCK_EXISTS
using ABI.CCK.Components;
#endif

namespace Ikeiwa.NeoHUD
{
    [ExecuteInEditMode]
    public class IkePlaceAtViewpoint : MonoBehaviour
    {
        public Transform hudRoot;

#if VRC_SDK_VRCSDK3 || CVR_CCK_EXISTS
        private void Start()
        {
            if (Application.isPlaying)
                return;

            UpdateObject();
        }

        private void Awake()
        {
            if (Application.isPlaying)
                return;

            UpdateObject();
        }

        private void Update()
        {
            if (Application.isPlaying)
                return;

            UpdateObject();
        }

        private void OnValidate()
        {
            if (Application.isPlaying)
                return;

            UpdateObject();
        }

        private void UpdateObject()
        {
            if (hudRoot)
            {
                hudRoot.localPosition = Vector3.zero;
                hudRoot.localRotation = Quaternion.identity;
                hudRoot.localScale = Vector3.one;
            }

#if VRC_SDK_VRCSDK3
            var avatar = GetComponentInParent<VRCAvatarDescriptor>();

            if (avatar)
            {
                Vector3 baseViewPoint = avatar.ViewPosition;

                Matrix4x4 avatarTransform = Matrix4x4.TRS(avatar.transform.position, avatar.transform.rotation, Vector3.one);

                baseViewPoint = avatarTransform.MultiplyPoint(baseViewPoint);

                transform.parent.position = baseViewPoint;
            }

#endif

#if CVR_CCK_EXISTS
            var cvrAvatar = GetComponentInParent<CVRAvatar>();

            if (cvrAvatar)
            {
                var parentConst = transform.parent.gameObject.GetComponent<ParentConstraint>();

                if (parentConst)
                {
                    parentConst.locked = false;
                    if(parentConst.sourceCount != 1)
                    {
                        parentConst.SetSources(new System.Collections.Generic.List<ConstraintSource>() { new ConstraintSource
                        {
                            sourceTransform = null,
                            weight = 1
                        }});
                    }

                    if (!parentConst.GetSource(0).sourceTransform)
                    {
                        Transform head = cvrAvatar.gameObject.GetComponent<Animator>().GetBoneTransform(HumanBodyBones.Head);

                        parentConst.SetSource(0, new ConstraintSource
                        {
                            sourceTransform = head,
                            weight = 1
                        });
                    }
                }

                Vector3 baseViewPoint = cvrAvatar.viewPosition;
                baseViewPoint = Matrix4x4.TRS(cvrAvatar.transform.position, cvrAvatar.transform.rotation, Vector3.one).MultiplyPoint(baseViewPoint);

                baseViewPoint = cvrAvatar.transform.InverseTransformPoint(baseViewPoint);

                transform.parent.localPosition = baseViewPoint;
                transform.parent.rotation = Quaternion.identity;

                var cvrParamStream = hudRoot.gameObject.GetComponent<CVRParameterStream>();

                if (cvrParamStream)
                {
                    foreach(var entry in cvrParamStream.entries)
                    {
                        entry.target = cvrAvatar.gameObject;
                        entry.targetType = CVRParameterStreamEntry.TargetType.AvatarAnimator;
                    }
                }

                if (parentConst)
                {
                    Transform head = parentConst.GetSource(0).sourceTransform;
                    Vector3 posOffset = head.InverseTransformPoint(transform.parent.position);
                    Quaternion rotOffset = Quaternion.Inverse(head.rotation * Quaternion.Inverse(transform.parent.rotation));

                    parentConst.SetTranslationOffset(0, posOffset);
                    parentConst.SetRotationOffset(0, rotOffset.eulerAngles);
                    parentConst.locked = true;
                }
            }
#endif
        }

        private Quaternion WorldToLocal(Quaternion worldRotation, Transform target)
        {
            var rotOffset = target.rotation * Quaternion.Inverse(target.localRotation);
            var rotWorld = worldRotation * rotOffset;
            var rotLocal = Quaternion.Inverse(rotOffset) * rotWorld;
            return rotLocal;
        }
#endif
    }
}