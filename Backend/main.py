from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
import twilio
from credentials import account_sid, auth_token, from_number

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///mydatabase.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

from twilio.rest import Client

def send_messages(phone_numbers, message):
    # Initialize Twilio client
    client = Client(account_sid, auth_token)

    # Ensure unique phone numbers
    unique_numbers = set(phone_numbers)

    # Send the message to each unique phone number
    for number in unique_numbers:
        try:
            message = client.messages.create(
                body=message,
                from_=from_number,
                to=number
            )
            
        except Exception as e:
            print(f"Failed to send message to {number}: {e}")

# Models
class School(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String, nullable=False)

class Student(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    phone_number = db.Column(db.String, nullable=False)
    emergency_phone = db.Column(db.String, nullable=False)
    name = db.Column(db.String, nullable=False)
    school_id = db.Column(db.Integer, db.ForeignKey('school.id'), nullable=False)

class Camera(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    school_id = db.Column(db.Integer, db.ForeignKey('school.id'), nullable=False)
    room_code = db.Column(db.String, nullable=False)

class Event(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    room_code = db.Column(db.String, nullable=False)
    event_type = db.Column(db.String, nullable=False)  # 'camera' or 'audio'
    timestamp = db.Column(db.DateTime, nullable=False)
    school_id = db.Column(db.Integer, db.ForeignKey('school.id'), nullable=False)

def initialize_db():
    db.create_all()

# Endpoints
@app.route('/add_school', methods=['POST'])
def add_school():
    data = request.json
    new_school = School(name=data['name'])
    db.session.add(new_school)
    db.session.commit()
    return jsonify({'message': 'School added successfully'}), 201

@app.route('/get_schools', methods=["POST"])
def get_schools():
    schools = School.query.all()
    final = []
    for school in schools:
        final.append({"id": school.id, "name": school.name})

    return jsonify({"data": final})

@app.route('/add_student', methods=['POST'])
def add_student():
    data = request.json
    # Check if a student with the same phone number already exists
    existing_student = Student.query.filter_by(phone_number=data['phone_number']).first()
    
    if existing_student:
        # If student exists, return the existing ID
        return jsonify({'message': 'Student already exists', 'id': existing_student.id}), 200
    else:
        # If student does not exist, create a new one
        new_student = Student(phone_number=data['phone_number'], emergency_phone=data['emergency_phone'],
                              name=data['name'], school_id=data['school_id'])
        db.session.add(new_student)
        db.session.commit()
        return jsonify({'message': 'Student added successfully', 'id': new_student.id}), 201

@app.route('/get_students', methods=['POST'])
def get_students():
    students = Student.query.all()
    student_list = []
    for student in students:
        student_data = {
            "id": student.id,
            "phone_number": student.phone_number,
            "emergency_phone": student.emergency_phone,
            "name": student.name,
            "school_id": student.school_id
        }
        student_list.append(student_data)

    return jsonify(student_list)

@app.route('/delete_students', methods=['POST'])
def delete_students():
    try:
        Student.query.delete()
        db.session.commit()
        return jsonify({'message': 'All students have been deleted'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500 

@app.route('/add_camera', methods=['POST'])
def add_camera():
    data = request.json
    new_camera = Camera(school_id=data['school_id'], room_code=data['room_code'])
    db.session.add(new_camera)
    db.session.commit()
    return jsonify({'message': 'Camera added successfully'}), 201

@app.route("/delete_events", methods=['POST'])
def delete_events():
    try:
        Event.query.delete()
        db.session.commit()
        return jsonify({'message': 'All events have been deleted'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/report_event', methods=['POST'])
def report_event():
    data = request.json
    last_event = Event.query.filter_by(room_code=data['room_code']).order_by(Event.timestamp.desc()).first()
    if last_event and (datetime.now() - last_event.timestamp).total_seconds() < 5:
        return jsonify({'message': 'Event not stored, another event occurred recently'}), 400
    new_event = Event(room_code=data['room_code'], event_type=data['event_type'],
                                 timestamp=datetime.now(), school_id=data['school_id'])
    
    all_students = Student.query.filter_by(school_id=data['school_id']).all()

    final_numbers = []

    for i in all_students:
        final_numbers.append("+1" + i.phone_number)
        final_numbers.append("+1" + i.emergency_phone)
    db.session.add(new_event)
    db.session.commit()

    m_text = f"EMERGENCY ALERT! A gunshot was detected in room {data['room_code']} through {data['event_type']} detection systems."
    send_messages(final_numbers, m_text)
    return jsonify({'message': 'Event reported successfully'}), 201

@app.route('/get_latest_event', methods=['POST'])
def get_latest_event():
    data = request.json
    school_id = data["school_id"]
    event = Event.query.filter_by(school_id=school_id).order_by(Event.timestamp.desc()).first()
    if event:
        return jsonify({'room_code': event.room_code, 'event_type': event.event_type,
                        'timestamp': event.timestamp.isoformat(), 'school_id': event.school_id})
    return jsonify({'message': 'No events found'}), 404

if __name__ == '__main__':
    with app.app_context():
        initialize_db()
    app.run(debug=True, port=8000)