#!/usr/bin/env python3
"""Recreate the old-style home backdrop colour-matched to the chosen concept.

The original home_bg.jpg remains untouched; this only changes colour and size,
not the warehouse arrangement. Requires Pillow and NumPy. Buttons and labels
are built at runtime by Godot rather than baked into the background.
"""
from pathlib import Path
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
COEFFICIENTS = [[1.2806292792765763, -0.1466065402353896, -0.24786716565776476], [1.1333648105624958, 1.9489790638991429, 0.22128187593039395], [-0.3791473356278643, -0.11216112459335903, 1.2175726631773929], [2.348563461417633, -6.368813079905645, -7.990210435144718]]
original=Image.open(ROOT/'assets/home/home_bg.jpg').convert('RGB').resize((704,1504),Image.Resampling.LANCZOS)
a=np.asarray(original,dtype=np.float64)
out=np.concatenate([a,np.ones((*a.shape[:2],1))],axis=2) @ np.array(COEFFICIENTS,dtype=np.float64)
Image.fromarray(np.clip(out,0,255).astype('uint8')).save(ROOT/'assets/home/home_bg_v59.jpg',quality=94)
print('Rebuilt old-style home background.')
