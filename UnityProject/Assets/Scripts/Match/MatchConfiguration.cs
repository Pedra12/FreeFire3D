using UnityEngine;

namespace FreeFire3D.Match
{
    [CreateAssetMenu(menuName = "FreeFire3D/Match Configuration", fileName = "MatchConfiguration")]
    public sealed class MatchConfiguration : ScriptableObject
    {
        [Min(1)] public int playersPerTeam = 4;
        [Min(0)] public int alliedBots = 3;
        [Min(1)] public int enemyBots = 4;
        public string playerCharacterId = "olivia";
        public bool startDirectlyInMatch = true;

        private void OnValidate()
        {
            playersPerTeam = Mathf.Max(1, playersPerTeam);
            alliedBots = Mathf.Clamp(alliedBots, 0, playersPerTeam - 1);
            enemyBots = Mathf.Max(1, enemyBots);
        }
    }
}
