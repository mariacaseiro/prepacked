//
//  ViewController.swift
//  luggageMaker
//
//  Created by María Caseiro Arias on 2/4/23.
//

import UIKit
import Foundation
import ChatGPTKit
import Alamofire
import SwiftyJSON

let apiOpenWeather = "api_key"

//function to close the keyboard clicking anywhere
extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

func getWeatherPrediction(city: String, days: String, completionHandler: @escaping (String) -> Void) {
    AF.request("https://pro.openweathermap.org/data/2.5/forecast/climate?q=\(city)&cnt=\(days)&units=metric&APPID=\(apiOpenWeather)").responseJSON { response in
        let json = JSON(response.value)
        
        var solution = ""
        if let forecasts = json["list"].array {
            for forecast in forecasts {
                let time = NSDate(timeIntervalSince1970: forecast["dt"].rawValue as! TimeInterval)
                let date = "For the "+time.description
                let max_temp = " the maximum temperature will be "+String(forecast["temp"]["max"].float!)
                let min_temp = "°C and the minimum will be "+String(forecast["temp"]["min"].float!)
                let humidity = "km/h. The humidity will have a percentage of "+String(forecast["humidity"].float!)
                let wind = "°C. There would be wind gusts of "+String(forecast["speed"].float!)
                let description = "hPa. The weather will be "+(forecast["weather"][0]["description"].string!)+". "

                solution += date + max_temp + min_temp + wind + humidity + description
            }
        }
        completionHandler(solution as String)
    }
}

class ViewController: UIViewController {
    
    //interface elements
    @IBOutlet var ubicationName: UITextField!
    @IBOutlet var luggageSize: UIButton!
    @IBOutlet var gender: UIButton!
    @IBOutlet var initDate: UIDatePicker!
    @IBOutlet var endDate: UIDatePicker!
    @IBOutlet var loadEl: UIActivityIndicatorView!
    
    //variables
    var luggageType = "Small (54x35x23cm)"
    var genderType = "Female"
    
    //chatGPT API
    let chattyGPT = ChatGPTKit(apiKey: "api_key")
    //chatGPT first configuration
    var history = [Message(role: .system, content: "From now on you will be a clothing recommender to prepare the luggage. In the following messages you will be given the days, the location, the size of the suitcase, the gender of the person who is going to use the luggage and the description of the weather on those dates in that location. You will have to recommend the type of clothing and the quantity needed to prepare the luggage and to provide a list with all the required items.")]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let setLuggageType = { (action: UIAction) in
            self.luggageType=action.title
        }
        
        let setGenderType = { (action: UIAction) in
            self.genderType=action.title
        }
        
        //init values for lugagge size
        luggageSize.menu = UIMenu(children: [
            UIAction(title: "Small (54x35x23cm)", handler: setLuggageType),
            UIAction(title: "Medium (65x40x25cm)", handler: setLuggageType),
            UIAction(title: "Large (75x46x30cm)", handler: setLuggageType)
        ])
        luggageSize.showsMenuAsPrimaryAction = true
        
        //init values for gender
        gender.menu = UIMenu(children: [
            UIAction(title: "Female", handler: setGenderType),
            UIAction(title: "Male", handler: setGenderType),
            UIAction(title: "Non-binary", handler: setGenderType),
            UIAction(title: "Other", handler: setGenderType)
        ])
        gender.showsMenuAsPrimaryAction = true
        
        //closing the keyboard
        self.hideKeyboardWhenTappedAround()
        
        self.loadEl.isHidden = true
    }
    
    @IBAction func showPrediction(sender: UIButton) {
        
        self.loadEl.isHidden = false
        self.loadEl.startAnimating()
        
        //check that all the fields have a value
        if(!ubicationName.hasText){
            let alertController = UIAlertController(title: "CAUTION", message: "Please, insert all the required fields.", preferredStyle: UIAlertController.Style.alert)
            alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            present(alertController, animated: true, completion: nil)
        }else{
            //get the number of days
            let days = Calendar.current.dateComponents([.day], from: initDate.date, to: endDate.date)
            
            //create the chatGPT message with the trip information
            let u = "Ubication: "+ubicationName.text!+". "
            let l = "Luggage size: "+luggageType+". "
            let d = "Number of days: "+String(days.day!+1)+". "
            let g = "Gender: "+genderType+". "
            let req = getWeatherPrediction(city: ubicationName.text!,days: String(days.day!+1)) { myRequest in
                var w = "Weather description: "+myRequest+"."
                let message = u+l+d+g+w
                
                //append the message for the chatGPT
                self.history.append(Message(role: .user, content: message))
                
                //call and show the chatGPT prediction
                Task { @MainActor in
                    switch try await self.chattyGPT.performCompletions(messages: self.history) {
                    case .success(let response):
                        let alertController = UIAlertController(title: "HERE IS MY OPINION ABOUT YOUR LUGGAGE!", message: response.choices![0].message.content, preferredStyle: UIAlertController.Style.actionSheet)
                        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                    case .failure(let error):
                        let alertController = UIAlertController(title: "WARNING!", message: "The connection could not be established", preferredStyle: UIAlertController.Style.alert)
                        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                        self.present(alertController, animated: true, completion: nil)
                        print(error)
                    }
                    self.loadEl.isHidden = true

                }
            }
        }
    }

}

