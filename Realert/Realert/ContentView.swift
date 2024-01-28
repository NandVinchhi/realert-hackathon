//
//  ContentView.swift
//  Realert
//
//  Created by Nand Vinchhi on 28/01/24.
//
import SwiftUI
import CoreML
import SoundAnalysis
import AVFoundation
import UIKit
import MapKit
import CoreLocation

enum Stage {
    case none
    case onboarding1
    case onboarding2
    case mainPage
}

struct School {
    var id: Int
    var name: String
}

struct ClassSchedule: Identifiable {
    var id: Int
    var startTime: Date
    var roomCode: String
}

struct WeekSchedule {
    var monday: [ClassSchedule]
    var tuesday: [ClassSchedule]
    var wednesday: [ClassSchedule]
    var thursday: [ClassSchedule]
    var friday: [ClassSchedule]
    var saturday: [ClassSchedule]
    var sunday: [ClassSchedule]
}

struct Alert: Equatable {
    var roomCode: String
    var alertType: String
    var timeStamp: String
    
    static func == (lhs: Alert, rhs: Alert) -> Bool {
            return
                lhs.roomCode == rhs.roomCode &&
                lhs.alertType == rhs.alertType &&
                lhs.timeStamp == rhs.timeStamp
        }
}

struct ContentView: View {
    @State var result: ClassificationResult = .init(result: "background", confidence: "100%", numThreats: 0, count: 0)
    @State var observer: ResultsObserver
    @State var audioEngine = AVAudioEngine()
    @State var audioStreamAnalyzer: SNAudioStreamAnalyzer?
    @State var inputFormat: AVAudioFormat?
    @State var currentStage: Stage = .none
    
    @State var name: String = ""
    @State var phone: String = ""
    @State var emergencyPhone: String = ""
    @State var schools: [School] = []
    
    @State var currentSchool: String = ""
    @State var currentSchoolId: Int = -1
    
    @State var studentId: Int = -1
    
    @State var weekSchedule: WeekSchedule = .init(monday: [], tuesday: [], wednesday: [], thursday: [], friday: [], saturday: [], sunday: [])
    
    @State var isTracking = false
    
    @State var currentAlert: Alert? = nil
    
    
    //Map Stuff
    @State var region = MKCoordinateRegion(
                center: .init(latitude: 37.5447, longitude: -77.44813),
                span: .init(latitudeDelta: 0.0018, longitudeDelta: 0.0018)
            )
        
        let locationManager = CLLocationManager()
        
        let room1 = [
            CLLocationCoordinate2D(latitude: 37.54459, longitude: -77.44839),
            CLLocationCoordinate2D(latitude: 37.54466, longitude: -77.44850),
            CLLocationCoordinate2D(latitude: 37.54457, longitude: -77.44860),
            CLLocationCoordinate2D(latitude: 37.54450, longitude: -77.44849)
        ]
        
        let room2 = [
            CLLocationCoordinate2D(latitude: 37.54474, longitude: -77.44870),
            CLLocationCoordinate2D(latitude: 37.54474, longitude: -77.44864),
            CLLocationCoordinate2D(latitude: 37.54468, longitude: -77.448645),
            CLLocationCoordinate2D(latitude: 37.54468, longitude: -77.44870)
        ]
        
        let room3 = [
            CLLocationCoordinate2D(latitude: 37.54496, longitude: -77.44844),
            CLLocationCoordinate2D(latitude: 37.54496, longitude: -77.44855),
            CLLocationCoordinate2D(latitude: 37.54504, longitude: -77.44855),
            CLLocationCoordinate2D(latitude: 37.54504, longitude: -77.44844)
        ]
        
        let hallway1 = [
            CLLocationCoordinate2D(latitude: 37.54467, longitude: -77.44851),
            CLLocationCoordinate2D(latitude: 37.54488, longitude: -77.44851),
            CLLocationCoordinate2D(latitude: 37.54489, longitude: -77.44862),
            CLLocationCoordinate2D(latitude: 37.54467, longitude: -77.44864),
            CLLocationCoordinate2D(latitude: 37.54464, longitude: -77.44856)
        ]
        
        let hallway2 = [
            CLLocationCoordinate2D(latitude: 37.54459, longitude: -77.44862),
            CLLocationCoordinate2D(latitude: 37.54458, longitude: -77.44869),
            CLLocationCoordinate2D(latitude: 37.54465, longitude: -77.44870),
            CLLocationCoordinate2D(latitude: 37.54466, longitude: -77.44863)
        ]
        
        let hallway3 = [
            CLLocationCoordinate2D(latitude: 37.54496, longitude: -77.44856),
            CLLocationCoordinate2D(latitude: 37.54506, longitude: -77.44856),
            CLLocationCoordinate2D(latitude: 37.54508, longitude: -77.44863),
            CLLocationCoordinate2D(latitude: 37.54496, longitude: -77.44863)
        ]
        
        @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.5447, longitude: -77.44813), span: MKCoordinateSpan(latitudeDelta: 0.0018, longitudeDelta: 0.0018)))
    
    //Map Stuff Ends
    
    var currentRoom: String {
        parseSchedule(s: weekSchedule)
    }
    
    func parseSchedule(s: WeekSchedule) -> String {
        var day: [ClassSchedule] = []
        
        let formatter = DateFormatter(); formatter.dateFormat = "E"
        let dayOfWeek: String = formatter.string(from: Date.now)
        
        switch dayOfWeek {
        case "Mon":
            day = s.monday
        case "Tue":
            day = s.tuesday
        case "Wed":
            day = s.wednesday
        case "Thu":
            day = s.thursday
        case "Fri":
            day = s.friday
        case "Sat":
            day = s.saturday
        case "Sun":
            day = s.sunday
        default:
            day = []
        }
        
        var finalRoomCode: String = "NA"
        
        if (day.count == 0) {
            return finalRoomCode
        }
        
        for i in (0...day.count - 1) {
            if day[i].startTime > Date.now {
                return finalRoomCode
            } else {
                finalRoomCode = day[i].roomCode
            }
        }
        
        return finalRoomCode
    }
    
    let baseUrl: String = "https://new-ravens-speak.loca.lt"
    
    private func convertDictToSchool(data: [String: Any]) -> School {
        return School(id: data["id"] as? Int ?? 0, name: data["name"] as? String ?? "")
    }
    
    private func convertDictArrayToSchools(data: [[String: Any]]) -> [School] {
        var final: [School] = []
        for i in (0...data.count - 1) {
            final.append(convertDictToSchool(data: data[i]))
        }
        return final
    }
    
    func getSchoolsRequest(completion: @escaping ([School]?, Error?) -> Void) {
            let url = URL(string: baseUrl + "/get_schools")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [:]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let data = json["data"] as? [[String: Any]] {
                        DispatchQueue.main.async {
                            completion(convertDictArrayToSchools(data: data), nil)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            }

            task.resume()
        }
    
    func addStudentRequest(completion: @escaping (Int?, Error?) -> Void) {
            let url = URL(string: baseUrl + "/add_student")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["phone_number": phone, "emergency_phone": emergencyPhone, "school_id": currentSchoolId, "name": name]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let data = json["id"] as? Int {
                        DispatchQueue.main.async {
                            completion(data, nil)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            }

            task.resume()
        }
    func addAlertRequest(completion: @escaping (Bool?, Error?) -> Void) {
            let url = URL(string: baseUrl + "/report_event")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["room_code": currentRoom, "event_type": "audio", "school_id": currentSchoolId]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let _ = json["message"] as? String {
                        DispatchQueue.main.async {
                            completion(true, nil)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            }

            task.resume()
        }
    
    func convertToTimeFormat(_ input: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS" // Input format
        inputFormatter.locale = Locale(identifier: "en_US_POSIX") // Set locale to posix
        inputFormatter.timeZone = TimeZone(abbreviation: "EST") // Set time zone to EST

        if let date = inputFormatter.date(from: input) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "h:mm a" // Output format
            return outputFormatter.string(from: date)
        } else {
            return ""
        }
    }

    
    func getAlertRequest(completion: @escaping (Alert?, Error?) -> Void) {
            let url = URL(string: baseUrl + "/get_latest_event")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["school_id": currentSchoolId]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let _ = json["school_id"] as? Int {
                        DispatchQueue.main.async {
                            completion(.init(roomCode: json["room_code"] as? String ?? "", alertType: json["event_type"] as? String ?? "", timeStamp: convertToTimeFormat(json["timestamp"] as? String ?? "")), nil)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(nil, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            }

            task.resume()
        }

    var body: some View {
        
        switch currentStage {
        case .none:
            Text("Loading...").onAppear() {
                getSchoolsRequest() { message, error in
                    schools = message!
                    currentStage = .onboarding1
                }
            }
        case .onboarding1:
            VStack(spacing: 16) {
                Text("Let's get started").font(.title).fontWeight(.bold)
                
                Menu {
                    ForEach(schools, id: \.id) { current in
                        Button {
                            currentSchoolId = current.id
                            currentSchool = current.name
                        } label: {
                            Text(current.name)
                        }
                    }
                    
                } label: {
                    HStack {
                        Text(currentSchoolId == -1 ? "Select your school": currentSchool)
                            .foregroundColor(currentSchoolId == -1 ? Color(UIColor.systemGray2): .black)
                        Spacer()
                        Image(systemName: "arrowtriangle.down.fill").foregroundColor(.black)
                    }
                     
                        .padding(10)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 360)
                        )
                }.frame(width: 360)
                
                TextField("Enter your name", text: $name)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 2)
                    )
                
                TextField("Enter your phone", text: $phone)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 2)
                    )
                
                TextField("Enter emergency phone", text: $emergencyPhone)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 2)
                    )
                
                Button {
                    addStudentRequest() { message, error in
                        studentId = message!
                        currentStage = .onboarding2
                    }
                } label: {
                    ZStack {
                        Text("Confirm").fontWeight(.semibold).foregroundColor(.white).zIndex(2)
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(.black).zIndex(1)
                            .frame(width: 360, height: 50)
                    }
                }.disabled(name == "" || phone.count != 10 || emergencyPhone.count != 10 || currentSchoolId == -1)
            
            }.padding()
            
        case .onboarding2:
            VStack(spacing: 10) {
                Text("Schedule").font(.title).fontWeight(.bold)
                
               
                ScrollView(showsIndicators: false)  {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Monday").font(.title3).fontWeight(.bold)
                            Spacer()
                            Button {
                                weekSchedule.monday.append(.init(id: weekSchedule.monday.count, startTime: .now, roomCode: ""))
                            } label: {
                                Image(systemName: "plus.app.fill").resizable().foregroundColor(.black).frame(width: 24, height: 24)
                            }
                            
                        }
                        ForEach(weekSchedule.monday) { element in
                            HStack (spacing: 10) {
                                TextField("Enter room code", text: $weekSchedule.monday[element.id].roomCode)
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                    .textInputAutocapitalization(.characters)
                                
                                DatePicker("", selection: $weekSchedule.monday[element.id].startTime, displayedComponents: .hourAndMinute).labelsHidden()
                                    .padding(3)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }.padding(1)
                        }
                        
                        HStack {
                            Text("Tuesday").font(.title3).fontWeight(.bold)
                            Spacer()
                            Button {
                                weekSchedule.tuesday.append(.init(id: weekSchedule.tuesday.count, startTime: .now, roomCode: ""))
                            } label: {
                                Image(systemName: "plus.app.fill").resizable().foregroundColor(.black).frame(width: 24, height: 24)
                            }
                            
                        }
                        ForEach(weekSchedule.tuesday) { element in
                            HStack (spacing: 10) {
                                TextField("Enter room code", text: $weekSchedule.tuesday[element.id].roomCode)
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                    .textInputAutocapitalization(.characters)
                                
                                DatePicker("", selection: $weekSchedule.tuesday[element.id].startTime, displayedComponents: .hourAndMinute).labelsHidden()
                                    .padding(3)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }.padding(1)
                        }
                        
                        HStack {
                            Text("Wednesday").font(.title3).fontWeight(.bold)
                            Spacer()
                            Button {
                                weekSchedule.wednesday.append(.init(id: weekSchedule.wednesday.count, startTime: .now, roomCode: ""))
                            } label: {
                                Image(systemName: "plus.app.fill").resizable().foregroundColor(.black).frame(width: 24, height: 24)
                            }
                            
                        }
                        ForEach(weekSchedule.wednesday) { element in
                            HStack (spacing: 10) {
                                TextField("Enter room code", text: $weekSchedule.wednesday[element.id].roomCode)
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                    .textInputAutocapitalization(.characters)
                                
                                DatePicker("", selection: $weekSchedule.wednesday[element.id].startTime, displayedComponents: .hourAndMinute).labelsHidden()
                                    .padding(3)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }.padding(1)
                        }
                        
                        HStack {
                            Text("Thursday").font(.title3).fontWeight(.bold)
                            Spacer()
                            Button {
                                weekSchedule.thursday.append(.init(id: weekSchedule.thursday.count, startTime: .now, roomCode: ""))
                            } label: {
                                Image(systemName: "plus.app.fill").resizable().foregroundColor(.black).frame(width: 24, height: 24)
                            }
                            
                        }
                        ForEach(weekSchedule.thursday) { element in
                            HStack (spacing: 10) {
                                TextField("Enter room code", text: $weekSchedule.thursday[element.id].roomCode)
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                    .textInputAutocapitalization(.characters)
                                
                                DatePicker("", selection: $weekSchedule.thursday[element.id].startTime, displayedComponents: .hourAndMinute).labelsHidden()
                                    .padding(3)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }.padding(1)
                        }
                        
                        HStack {
                            Text("Friday").font(.title3).fontWeight(.bold)
                            Spacer()
                            Button {
                                weekSchedule.friday.append(.init(id: weekSchedule.friday.count, startTime: .now, roomCode: ""))
                            } label: {
                                Image(systemName: "plus.app.fill").resizable().foregroundColor(.black).frame(width: 24, height: 24)
                            }
                            
                        }
                        ForEach(weekSchedule.friday) { element in
                            HStack (spacing: 10) {
                                TextField("Enter room code", text: $weekSchedule.friday[element.id].roomCode)
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                    .textInputAutocapitalization(.characters)
                                
                                DatePicker("", selection: $weekSchedule.friday[element.id].startTime, displayedComponents: .hourAndMinute).labelsHidden()
                                    .padding(3)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }.padding(1)
                        }
                        
                        HStack {
                            Text("Saturday").font(.title3).fontWeight(.bold)
                            Spacer()
                            Button {
                                weekSchedule.saturday.append(.init(id: weekSchedule.saturday.count, startTime: .now, roomCode: ""))
                            } label: {
                                Image(systemName: "plus.app.fill").resizable().foregroundColor(.black).frame(width: 24, height: 24)
                            }
                            
                        }
                        ForEach(weekSchedule.saturday) { element in
                            HStack (spacing: 10) {
                                TextField("Enter room code", text: $weekSchedule.saturday[element.id].roomCode)
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                    .textInputAutocapitalization(.characters)
                                
                                DatePicker("", selection: $weekSchedule.saturday[element.id].startTime, displayedComponents: .hourAndMinute).labelsHidden()
                                    .padding(3)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }.padding(1)
                        }

                        HStack {
                            Text("Sunday").font(.title3).fontWeight(.bold)
                            Spacer()
                            Button {
                                weekSchedule.sunday.append(.init(id: weekSchedule.sunday.count, startTime: .now, roomCode: ""))
                            } label: {
                                Image(systemName: "plus.app.fill").resizable().foregroundColor(.black).frame(width: 24, height: 24)
                            }
                            
                        }
                        ForEach(weekSchedule.sunday) { element in
                            HStack (spacing: 10) {
                                TextField("Enter room code", text: $weekSchedule.sunday[element.id].roomCode)
                                    .padding(10)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                                    .textInputAutocapitalization(.characters)
                                
                                DatePicker("", selection: $weekSchedule.sunday[element.id].startTime, displayedComponents: .hourAndMinute).labelsHidden()
                                    .padding(3)
                                    .background(Color.white)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.black, lineWidth: 2)
                                    )
                            }.padding(1)
                        }

                        
                    }
                }

                Spacer()
                
                Button {
                    currentStage = .mainPage
                } label: {
                    ZStack {
                        Text("Confirm").fontWeight(.semibold).foregroundColor(.white).zIndex(2)
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(.black).zIndex(1)
                            .frame(width: 360, height: 50)
                    }
                }
            }.padding()
            
        case .mainPage:
            
            ZStack {
                
                Map(position: $cameraPosition)
                            {
                                MapPolygon(coordinates: room1)
                                    .foregroundStyle(currentAlert?.roomCode ?? "" == "EGR1313" ? Color.red : Color.green)
                                    
                                Annotation(
                                        "EGR 1313",
                                        coordinate: CLLocationCoordinate2D(
                                            latitude: 37.54465
                                        , longitude: -77.448495)
                                        , anchor: .top
                                    ) {
                                        Image(systemName: "rays")
                                            .foregroundStyle(.clear)
                                            .background (Color.clear)
                                    }
                                
                                MapPolygon(coordinates: room2)
                                    .foregroundStyle(currentAlert?.roomCode ?? "" == "EGR2308" ? Color.red : Color.green)
                                Annotation(
                                        "EGR 2308",
                                        coordinate: CLLocationCoordinate2D(
                                            latitude: 37.54475
                                        , longitude: -77.44867125),
                                        anchor: .bottom
                                    ) {
                                        Image(systemName: "rays")
                                            .foregroundStyle(.clear)
                                            .background (Color.clear)
                                    }
                                
                                MapPolygon(coordinates: room3)
                                    .foregroundStyle(currentAlert?.roomCode ?? "" == "EAST1232" ? Color.red : Color.green)
                                Annotation(
                                        "EAST 1232",
                                        coordinate: CLLocationCoordinate2D(
                                            latitude: 37.54504
                                        , longitude: -77.448495),
                                        anchor: .bottom
                                    ) {
                                        Image(systemName: "rays")
                                            .foregroundStyle(.clear)
                                            .background (Color.clear)
                                    }
                                
                                MapPolygon(coordinates: hallway1)
                                    .foregroundStyle(currentAlert?.roomCode ?? "" == "H0001" ? Color.red : Color.green)
                                Annotation(
                                        "Main Hall",
                                        coordinate: CLLocationCoordinate2D(
                                            latitude: 37.54487
                                        , longitude: -77.448598),
                                        anchor: .bottom
                                    ) {
                                        Image(systemName: "rays")
                                            .foregroundStyle(.clear)
                                            .background (Color.clear)
                                    }
                                
                                MapPolygon(coordinates: hallway2)
                                    .foregroundStyle(currentAlert?.roomCode ?? "" == "H0002" ? Color.red : Color.green)
                  
                                MapPolygon(coordinates: hallway3)
                                    .foregroundStyle(currentAlert?.roomCode ?? "" == "H0003" ? Color.red : Color.green)
                                
                            }
                VStack {
                    Spacer()
                    
                    ZStack {
                        Button {
                            isTracking = true
                            
                        } label: {
                            Text("start").foregroundColor(.clear)
                        }.zIndex(3)
                            .offset(x: -150, y: -50)
                        
                        if let currentAlert {
                            RoundedRectangle(cornerRadius: 20).frame(width: 365, height: 132).foregroundColor(.red).padding().overlay {
                                VStack(spacing: 6) {
                                    Text("\(currentAlert.timeStamp) in room \(currentAlert.roomCode)").font(.system(size: 20)).fontWeight(.medium).foregroundColor(.white)
                                    Text("EMERGENCY ALERT").font(.title).foregroundColor(.white).fontWeight(.bold)
                                    Text("Detected through \(currentAlert.alertType)").font(.system(size: 20)).fontWeight(.medium).foregroundColor(.white)
                                    Spacer()
                                }.padding(.top, 32)
                            
                            }.zIndex(2)
                        } else {
                            RoundedRectangle(cornerRadius: 20).frame(width: 365, height: 132).foregroundColor(.white).padding().overlay {
                                VStack(spacing: 6) {
                                    Text("Tracking room \(currentRoom)").font(.system(size: 20)).fontWeight(.medium).foregroundColor(.black)
                                    Text(result.result == "background" || !isTracking ? "NO THREATS" : "THREAT DETECTED").font(.title).foregroundColor(.black).fontWeight(.bold)
                                    Text("\(isTracking ? result.confidence: "100.00%") confidence").font(.system(size: 20)).fontWeight(.medium).foregroundColor(.black)
                                    Spacer()
                                }.padding(.top, 32)
                            }.zIndex(2)
                        }
                        
                        
                        RoundedRectangle(cornerRadius: 21).frame(width: 369, height: 136).foregroundColor(Color(UIColor.darkGray)).padding().zIndex(1)
                    }
                    
                    
                }
            }
            .onAppear() {
                observer = ResultsObserver(result: $result)
                setupAudio()
                startAudioStream()
            }.onChange(of: result.count) { newValue in
                
                if (result.numThreats >= 3) {
                    if (isTracking) {
                    
                        result.numThreats = 0
                        Task {
                            currentAlert = .init(roomCode: currentRoom, alertType: "audio", timeStamp: getCurrentTimeString())
                        }
                        
                        addAlertRequest() { message, error in
                            print("success")
                        }
                    }
                    
                } else {
                    getAlertRequest() { message, error in
                        Task {
                            currentAlert = message
                        }
                        
                    }
                }
            }
        }
    }
    
    private func getCurrentTimeString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a" // "a" represents AM/PM
        return dateFormatter.string(from: Date())
    }

    private func setupAudio() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            let inputNode = audioEngine.inputNode
            inputFormat = inputNode.outputFormat(forBus: 0)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    private func startAudioStream() {
        let request = try! SNClassifySoundRequest(mlModel: RealertSoundClassifier().model)
        audioStreamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat!)

        do {
            try audioEngine.start()
            let inputNode = audioEngine.inputNode
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
                self.audioStreamAnalyzer?.analyze(buffer, atAudioFramePosition: 0)
            }
            try audioStreamAnalyzer?.add(request, withObserver: observer)
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }
}

struct ClassificationResult {
    var result: String
    var confidence: String
    var numThreats: Int
    var count: Int
}

/// An observer that receives results from a classify sound request.
class ResultsObserver: NSObject, SNResultsObserving {
    @Binding var  classificationResult: ClassificationResult
    
    init (result: Binding<ClassificationResult>) {
        _classificationResult = result
    }
    /// Notifies the observer when a request generates a prediction.
    func request(_ request: SNRequest, didProduce result: SNResult) {
        // Downcast the result to a classification result.
        guard let result = result as? SNClassificationResult else  { return }


        // Get the prediction with the highest confidence.
        guard let classification = result.classifications.first else { return }
        
        let percent = classification.confidence * 100.0
        let percentString = String(format: "%.2f%%", percent)

        classificationResult.result = classification.identifier
        classificationResult.confidence = percentString
        if (classification.identifier == "background") {
            classificationResult.numThreats = 0
        } else {
            classificationResult.numThreats += 1
        }
        
        classificationResult.count += 1
    }

    /// Notifies the observer when a request generates an error.
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("The analysis failed: \(error.localizedDescription)")
    }

    /// Notifies the observer when a request is complete.
    func requestDidComplete(_ request: SNRequest) {
        print("The request completed successfully!")
    }
}

//
//#Preview {
//    ContentView()
//}
