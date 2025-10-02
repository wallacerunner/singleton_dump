import face_recognition
import cv2
import dlib
import numpy as np

folder = '/stuff/tmp/'

# Load a sample picture and learn how to recognize it.
image_of_person = face_recognition.load_image_file(folder + "me.jpg")
person_face_encoding = face_recognition.face_encodings(image_of_person)[0]

# Create arrays of known face encodings and their names
known_face_encodings = [
    person_face_encoding
]
known_face_names = [
    "Person Name"
]

# Initialize some variables
face_locations = []
face_encodings = []
face_names = []

# Load the pre-trained dlib shape predictor model
predictor_path = folder + "shape_predictor_68_face_landmarks.dat"
detector = dlib.get_frontal_face_detector()
predictor = dlib.shape_predictor(predictor_path)

# Load the avatar image and its parts
avatar = cv2.imread('avatar.png', cv2.IMREAD_UNCHANGED)
avatar_mouth = cv2.imread('avatar_mouth.png', cv2.IMREAD_UNCHANGED)
avatar_left_eye = cv2.imread('avatar_left_eye.png', cv2.IMREAD_UNCHANGED)
avatar_right_eye = cv2.imread('avatar_right_eye.png', cv2.IMREAD_UNCHANGED)

# Open a video stream
video_capture = cv2.VideoCapture(0)

def apply_affine_transform(src, src_tri, dst_tri, size):
    """ Apply affine transform calculated using src_tri and dst_tri to src and output an image of size. """
    warp_mat = cv2.getAffineTransform(np.float32(src_tri), np.float32(dst_tri))
    dst = cv2.warpAffine(src, warp_mat, (size[0], size[1]), None, flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT_101)
    return dst

def warp_triangle(img1, img2, t1, t2):
    """ Warps and alpha blends triangular regions from img1 and img2 to img2. """
    # Find bounding rectangle for each triangle
    r1 = cv2.boundingRect(np.float32([t1]))
    r2 = cv2.boundingRect(np.float32([t2]))

    # Offset points by left top corner of the respective rectangles
    t1_rect = []
    t2_rect = []
    t2_rect_int = []

    for i in range(3):
        t1_rect.append(((t1[i][0] - r1[0]), (t1[i][1] - r1[1])))
        t2_rect.append(((t2[i][0] - r2[0]), (t2[i][1] - r2[1])))
        t2_rect_int.append(((t2[i][0] - r2[0]), (t2[i][1] - r2[1])))

    # Get mask by filling triangle
    mask = np.zeros((r2[3], r2[2], 3), dtype = np.float32)
    cv2.fillConvexPoly(mask, np.int32(t2_rect_int), (1.0, 1.0, 1.0), 16, 0)

    # Apply warpImage to small rectangular patches
    img1_rect = img1[r1[1]:r1[1] + r1[3], r1[0]:r1[0] + r1[2]]
    size = (r2[2], r2[3])
    img2_rect = apply_affine_transform(img1_rect, t1_rect, t2_rect, size)

    img2_rect = img2_rect * mask

    # Copy triangular region of the rectangular patch to the output image
    img2[r2[1]:r2[1] + r2[3], r2[0]:r2[0] + r2[2]] = img2[r2[1]:r2[1] + r2[3], r2[0]:r2[0] + r2[2]] * ((1.0, 1.0, 1.0) - mask)
    img2[r2[1]:r2[1] + r2[3], r2[0]:r2[0] + r2[2]] = img2[r2[1]:r2[1] + r2[3], r2[0]:r2[0] + r2[2]] + img2_rect

while True:
    # Grab a single frame of video
    ret, frame = video_capture.read()

    # Resize frame of video to 1/4 size for faster face recognition processing
    small_frame = cv2.resize(frame, (0, 0), fx=0.25, fy=0.25)

    # Convert the image from BGR color (which OpenCV uses) to RGB color (which face_recognition uses)
    rgb_small_frame = small_frame[:, :, ::-1]

    # Find all the faces and face encodings in the current frame of video
    face_locations = face_recognition.face_locations(rgb_small_frame)
    face_encodings = face_recognition.face_encodings(rgb_small_frame, face_locations)

    face_names = []
    for face_encoding in face_encodings:
        # See if the face is a match for the known face(s)
        matches = face_recognition.compare_faces(known_face_encodings, face_encoding)
        name = "Unknown"

        # If a match was found in known_face_encodings, use the first one.
        if True in matches:
            first_match_index = matches.index(True)
            name = known_face_names[first_match_index]

        face_names.append(name)

    # Create a blank image for drawing facial landmarks
    landmark_image = np.zeros_like(frame, dtype=np.uint8)

    # Convert the image to grayscale
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    # Detect faces in the grayscale image
    rects = detector(gray, 0)

    # Loop over the face detections
    for rect in rects:
        # Get the facial landmarks
        shape = predictor(gray, rect)

        # Extract specific landmarks for the mouth
        mouth_points = np.array([[p.x, p.y] for p in shape.parts()[48:68]])

        # Define triangles for morphing
        mouth_triangles = [
            (mouth_points[0], mouth_points[6], mouth_points[3]),
            (mouth_points[6], mouth_points[10], mouth_points[3]),
            (mouth_points[3], mouth_points[10], mouth_points[7]),
            (mouth_points[7], mouth_points[10], mouth_points[9]),
            (mouth_points[7], mouth_points[9], mouth_points[8])
        ]

        # Define corresponding triangles on the avatar
        avatar_height, avatar_width = avatar_mouth.shape[:2]
        avatar_mouth_points = [
            [0, avatar_height // 2],
            [avatar_width // 2, avatar_height // 2],
            [avatar_width // 4, 0]
        ]

        # Warp triangles from the detected mouth to the avatar's mouth
        for i in range(len(mouth_triangles)):
            t1 = [avatar_mouth_points[0], avatar_mouth_points[1], avatar_mouth_points[2]]
            t2 = [mouth_triangles[i][0], mouth_triangles[i][1], mouth_triangles[i][2]]
            warp_triangle(avatar_mouth, landmark_image, t1, t2)

    # Display the resulting image with landmarks and morphed avatar
    cv2.imshow('Facial Landmarks with Morphed Avatar', landmark_image)

    # Hit 'q' on the keyboard to quit!
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

# Release handle to the webcam
video_capture.release()
cv2.destroyAllWindows()
