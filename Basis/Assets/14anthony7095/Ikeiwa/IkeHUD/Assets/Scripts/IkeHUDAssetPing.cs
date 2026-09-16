using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Ikeiwa.NeoHUD
{
    [CreateAssetMenu(fileName = "IkeAssetPing.asset", menuName = "Ikeiwa/IkeHUD/Asset Ping")]
    public class IkeHUDAssetPing : ScriptableObject
    {
        public Object assetToPing;
        public bool isCVR;
    }
}