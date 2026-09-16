#if UNITY_EDITOR
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if VRC_SDK_VRCSDK3
using VRC.SDK3.Avatars.Components;
#endif

[ExecuteInEditMode]
public class IkePingPointerPlacer : MonoBehaviour
{
    public bool isRight;

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

    private int updatetime = 0;
    private void Update()
    {
        if (Application.isPlaying)
            return;

        updatetime--;
        if (updatetime <= 0)
        {
            updatetime = 10;
            UpdateObject(); 
        }
    }

    private void OnValidate()
    {
        if (Application.isPlaying)
            return;

        UpdateObject();
    }

    private void UpdateObject()
    {
#if VRC_SDK_VRCSDK3
        var avatar = GetComponentInParent<VRCAvatarDescriptor>();

        if (avatar)
        {
            var animator = avatar.GetComponent<Animator>();

            if (animator)
            {
                Vector3 pos = Vector3.zero;
                Vector3 dir = Vector3.zero;

                if (isRight)
                {
                    var Forwarm = animator.GetBoneTransform(HumanBodyBones.RightLowerArm).position;
                    var handPos = animator.GetBoneTransform(HumanBodyBones.RightHand).position;
                    var handForward = animator.GetBoneTransform(HumanBodyBones.RightHand).up;

                    pos = handPos;

                    var armForward = (handPos - Forwarm).normalized;

                    dir = armForward;
                }
                else
                {
                    var Forwarm = animator.GetBoneTransform(HumanBodyBones.LeftLowerArm).position;
                    var handPos = animator.GetBoneTransform(HumanBodyBones.LeftHand).position;
                    var handForward = animator.GetBoneTransform(HumanBodyBones.LeftHand).up;

                    pos = handPos;

                    var armForward = (handPos - Forwarm).normalized;

                    dir = armForward;
                }

                transform.parent.position = pos;
                transform.parent.up = -dir;
            }
        }
#endif
    }
}
#endif