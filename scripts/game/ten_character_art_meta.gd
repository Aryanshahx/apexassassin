extends RefCounted
## Hand/part geometry of ten reference-guided character redraws.
const LOOK_DATA := {
  "standard": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      923.65,
      142.92
    ],
    "elbow": [
      668.44,
      132.71
    ],
    "wrist": [
      515.31,
      275.62
    ],
    "free_shoulder": [
      990.0,
      625.0
    ],
    "hip_a": [
      1015.0,
      370.0
    ],
    "hip_b": [
      1015.0,
      410.0
    ],
    "origins": {
      "torso": [
        685,
        91
      ],
      "upper": [
        531,
        56
      ],
      "forearm": [
        401,
        68
      ],
      "hand": [
        399,
        311
      ],
      "free_arm": [
        523,
        468
      ]
    },
    "fist": [
      500.36,
      380.11
    ]
  },
  "shadow": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      885.26,
      144.47
    ],
    "elbow": [
      654.1,
      139.66
    ],
    "wrist": [
      528.89,
      291.83
    ],
    "free_shoulder": [
      990.0,
      625.0
    ],
    "hip_a": [
      1015.0,
      370.0
    ],
    "hip_b": [
      1015.0,
      410.0
    ],
    "origins": {
      "torso": [
        688,
        59
      ],
      "upper": [
        520,
        37
      ],
      "forearm": [
        414,
        73
      ],
      "hand": [
        410,
        311
      ],
      "free_arm": [
        519,
        458
      ]
    },
    "fist": [
      506.03,
      384.33
    ]
  },
  "speed_10": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      975.0,
      146.0
    ],
    "elbow": [
      675.0,
      137.0
    ],
    "wrist": [
      595.0,
      247.0
    ],
    "free_shoulder": [
      990.0,
      620.0
    ],
    "hip_a": [
      1015.0,
      370.0
    ],
    "hip_b": [
      1015.0,
      410.0
    ],
    "origins": {
      "torso": [
        519,
        156
      ],
      "upper": [
        556,
        4
      ],
      "forearm": [
        469,
        106
      ],
      "hand": [
        421,
        219
      ],
      "free_arm": [
        550,
        429
      ]
    },
    "fist": [
      530.0,
      339.0
    ]
  },
  "health_10": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      852.19,
      153.12
    ],
    "elbow": [
      668.44,
      122.5
    ],
    "wrist": [
      535.73,
      321.56
    ],
    "free_shoulder": [
      990.0,
      625.0
    ],
    "hip_a": [
      1015.0,
      370.0
    ],
    "hip_b": [
      1015.0,
      410.0
    ],
    "origins": {
      "torso": [
        601,
        52
      ],
      "upper": [
        534,
        50
      ],
      "forearm": [
        409,
        63
      ],
      "hand": [
        388,
        311
      ],
      "free_arm": [
        639,
        500
      ]
    },
    "fist": [
      506.82,
      414.59
    ]
  },
  "speed_20": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      885.26,
      144.47
    ],
    "elbow": [
      654.1,
      139.66
    ],
    "wrist": [
      528.89,
      291.83
    ],
    "free_shoulder": [
      990.0,
      625.0
    ],
    "hip_a": [
      1015.0,
      370.0
    ],
    "hip_b": [
      1015.0,
      410.0
    ],
    "origins": {
      "torso": [
        745,
        61
      ],
      "upper": [
        520,
        35
      ],
      "forearm": [
        415,
        72
      ],
      "hand": [
        410,
        311
      ],
      "free_arm": [
        523,
        460
      ]
    },
    "fist": [
      505.6,
      384.01
    ]
  },
  "health_20": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      885.26,
      144.47
    ],
    "elbow": [
      654.1,
      139.66
    ],
    "wrist": [
      528.89,
      291.83
    ],
    "free_shoulder": [
      990.0,
      625.0
    ],
    "hip_a": [
      1015.0,
      370.0
    ],
    "hip_b": [
      1015.0,
      410.0
    ],
    "origins": {
      "torso": [
        708,
        54
      ],
      "upper": [
        520,
        35
      ],
      "forearm": [
        415,
        69
      ],
      "hand": [
        410,
        311
      ],
      "free_arm": [
        519,
        462
      ]
    },
    "fist": [
      506.13,
      383.65
    ]
  },
  "speed_30": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      885.26,
      144.47
    ],
    "elbow": [
      654.1,
      139.66
    ],
    "wrist": [
      528.89,
      291.83
    ],
    "free_shoulder": [
      990.0,
      625.0
    ],
    "hip_a": [
      1015.0,
      370.0
    ],
    "hip_b": [
      1015.0,
      410.0
    ],
    "origins": {
      "torso": [
        691,
        58
      ],
      "upper": [
        520,
        36
      ],
      "forearm": [
        415,
        70
      ],
      "hand": [
        410,
        311
      ],
      "free_arm": [
        519,
        460
      ]
    },
    "fist": [
      506.07,
      383.54
    ]
  },
  "health_30": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      852.19,
      153.12
    ],
    "elbow": [
      668.44,
      122.5
    ],
    "wrist": [
      535.73,
      321.56
    ],
    "free_shoulder": [
      990.0,
      625.0
    ],
    "hip_a": [
      1015.0,
      370.0
    ],
    "hip_b": [
      1015.0,
      410.0
    ],
    "origins": {
      "torso": [
        601,
        52
      ],
      "upper": [
        534,
        50
      ],
      "forearm": [
        409,
        63
      ],
      "hand": [
        388,
        311
      ],
      "free_arm": [
        639,
        500
      ]
    },
    "fist": [
      506.82,
      414.59
    ]
  },
  "speed_40": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      885.26,
      144.47
    ],
    "elbow": [
      654.1,
      139.66
    ],
    "wrist": [
      528.89,
      291.83
    ],
    "free_shoulder": [
      990.0,
      625.0
    ],
    "hip_a": [
      1015.0,
      370.0
    ],
    "hip_b": [
      1015.0,
      410.0
    ],
    "origins": {
      "torso": [
        739,
        57
      ],
      "upper": [
        521,
        32
      ],
      "forearm": [
        416,
        73
      ],
      "hand": [
        412,
        311
      ],
      "free_arm": [
        520,
        461
      ]
    },
    "fist": [
      506.57,
      384.07
    ]
  },
  "health_40": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      900.0,
      150.0
    ],
    "elbow": [
      660.0,
      145.0
    ],
    "wrist": [
      530.0,
      303.0
    ],
    "free_shoulder": [
      990.0,
      625.0
    ],
    "hip_a": [
      1015.0,
      370.0
    ],
    "hip_b": [
      1015.0,
      410.0
    ],
    "origins": {
      "torso": [
        699,
        57
      ],
      "upper": [
        525,
        37
      ],
      "forearm": [
        425,
        83
      ],
      "hand": [
        425,
        311
      ],
      "free_arm": [
        545,
        460
      ]
    },
    "fist": [
      520.36,
      372.72
    ]
  }
}
const HAND_GRIP_CENTRES := {
  "standard": [
    500.36,
    380.11
  ],
  "shadow": [
    506.03,
    384.33
  ],
  "speed_10": [
    530.0,
    339.0
  ],
  "health_10": [
    506.82,
    414.59
  ],
  "speed_20": [
    505.6,
    384.01
  ],
  "health_20": [
    506.13,
    383.65
  ],
  "speed_30": [
    506.07,
    383.54
  ],
  "health_30": [
    506.82,
    414.59
  ],
  "speed_40": [
    506.57,
    384.07
  ],
  "health_40": [
    520.36,
    372.72
  ],
  "red_scarf": [
    514.0,
    366.0
  ]
}
const RED_HAND_ORIGIN := [426, 254]
const WEAPON_GRIP := {
  "thor": [405.0, 170.0],
  "aurora": [351.0, 92.0],
  "wolverine": [341.0, 190.0],
  "dracula": [345.0, 92.0],
  "leviathan": [551.0, 328.0],
}
