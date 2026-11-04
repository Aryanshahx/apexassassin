extends RefCounted
## Generated from private artwork; coordinates are on the normalized 1514x784 canvas.
const LOOK_DATA := {
  "white_hood": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      878.42,
      145.54
    ],
    "elbow": [
      645.54,
      140.69
    ],
    "wrist": [
      519.41,
      294.0
    ],
    "fist": [
      498.06,
      378.42
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
        681,
        45
      ],
      "upper": [
        513,
        17
      ],
      "forearm": [
        408,
        77
      ],
      "hand": [
        403,
        311
      ],
      "free_arm": [
        510,
        458
      ]
    }
  },
  "blue_tactical": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      893.02,
      173.54
    ],
    "elbow": [
      637.81,
      158.23
    ],
    "wrist": [
      525.52,
      313.4
    ],
    "fist": [
      503.06,
      398.12
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
        682,
        71
      ],
      "upper": [
        509,
        38
      ],
      "forearm": [
        413,
        96
      ],
      "hand": [
        412,
        311
      ],
      "free_arm": [
        514,
        468
      ]
    }
  },
  "green_fighter": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      842.88,
      144.47
    ],
    "elbow": [
      630.02,
      139.66
    ],
    "wrist": [
      523.12,
      295.69
    ],
    "fist": [
      500.96,
      375.63
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
        648,
        55
      ],
      "upper": [
        510,
        35
      ],
      "forearm": [
        414,
        85
      ],
      "hand": [
        410,
        311
      ],
      "free_arm": [
        518,
        462
      ]
    }
  },
  "yellow_hazmat": {
    "centre": [
      970.0,
      390.0
    ],
    "shoulder": [
      862.6,
      151.9
    ],
    "elbow": [
      642.1,
      137.2
    ],
    "wrist": [
      521.56,
      295.96
    ],
    "fist": [
      499.02,
      380.24
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
        648,
        49
      ],
      "upper": [
        509,
        21
      ],
      "forearm": [
        410,
        72
      ],
      "hand": [
        402,
        311
      ],
      "free_arm": [
        513,
        463
      ]
    }
  }
}
const WEAPON_GRIP := {
  "thor": [405.0, 170.0],
  "aurora": [351.0, 92.0],
  "wolverine": [341.0, 190.0],
  "dracula": [345.0, 92.0],
  "leviathan": [551.0, 328.0],
}
const RED_HAND_ORIGIN := [426, 254]

# Centres of the visible hand-layer alpha, in the same source coordinate space.
# Every weapon grip is placed here and drawn immediately behind the fist.
const HAND_GRIP_CENTRES := {
	"red_scarf": [514.0, 366.0], "white_hood": [502.6, 384.3],
	"blue_tactical": [509.2, 388.7], "green_fighter": [505.9, 383.5],
	"yellow_hazmat": [504.3, 388.4],
}
