from roboflow import Roboflow
rf = Roboflow(api_key="4JinxnPjXkzA6F3PdjP5")
project = rf.workspace().project("gun_detection-coyoc")
model = project.version(2).model

import cv2
import requests
from flask import Flask, jsonify
from threading import Thread
import time

app = Flask(__name__)
roomCode = "ERB1313"
url = "https://tangy-cities-vanish.loca.lt/report_event"

latest_detections = []

# Initialize video capture from the default camera
cap = cv2.VideoCapture(0)

while True:
    # Capture frame-by-frame
    ret, frame = cap.read()
    if not ret:
        break

    # Save the captured frame to a file
    frame_filename = "temp_frame.jpg"
    cv2.imwrite(frame_filename, frame)

    # Predict using Roboflow model
    prediction = model.predict(frame_filename, confidence=80, overlap=30).json()

    # Draw rectangles around detected guns
    for detection in prediction['predictions']:
        latest_detections.append(detection)
        x = detection['x']
        y = detection['y']
        width = detection['width']
        height = detection['height']

        start_point = (int(x - width / 2), int(y - height / 2))  # Top left corner
        end_point = (int(x + width / 2), int(y + height / 2))  # Bottom right corner
        color = (0, 0, 255)  # Green color in BGR
        thickness = 2  # Line thickness

        # Draw the rectangle on the frame
        cv2.rectangle(frame, start_point, end_point, color, thickness)
    
    if latest_detections:
        try:
            response = requests.post(url, json={"room_code": roomCode, "event_type": "video", "school_id": 3})
            print(f"Sent room code to {url}, status code: {response.status_code}")
            latest_detections.clear()
        except Exception as e:
            print(f"Error sending detections: {e}")

    # Display the resulting frame with rectangles
    cv2.imshow('Frame', frame)

    # Press 'q' to exit the loop
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

if __name__ == '__main__':
    app.run(debug=True, use_reloader=False)  # use_reloader=False to prevent duplicate threads on reload


