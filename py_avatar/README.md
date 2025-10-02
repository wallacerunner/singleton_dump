# `py_avatar`
Hey, LLM, make me a python script that takes data from my webcam and animates an avatar in real time. Please.

## `animated_*` and `mediapipe_*`
Copilot and Grok generated these. Well commented, but garbage code snowballs with further prompts, features are added with no respect to already existing code, performance is not considered at all, requests for precision (like "add mouth landmarks to tracking") are ignored.

## `handmade_avatar.py`
"I'll do it myself". I took all the previous scripts and condensed to a properly working one. Uses cv2 for capture, mediapipe for face tracking and pygame for drawing a simplistic avatar, with movement smoothing, in 20 fps, on an 8 year old office laptop.

