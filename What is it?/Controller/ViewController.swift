//
//  ViewController.swift
//  What is it?
//
//  Created by Ahmed Ramy on 3/24/18.
//  Copyright © 2018 Ahmed Ramy. All rights reserved.
//

import UIKit
import Vision
import CoreML
import Alamofire
import SwiftyJSON
import SVProgressHUD
import SDWebImage

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    //MARK:- Outlets
    @IBOutlet weak var imageTaken: UIImageView!
    @IBOutlet weak var cameraBtn: UIBarButtonItem!
    @IBOutlet weak var infoTextView: UITextView!
    
    //MARK:- Constants
    let APIURL = "https://en.wikipedia.org/w/api.php"
    
    //MARK:- Instance Variables
    let imagePicker = UIImagePickerController()
    var objectName = ""
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        //MARK:- imagePicker Settings
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = false
        
        //MARK:- UI Customization
        infoTextView.layer.masksToBounds = true
//        infoTextView.layer.cornerRadius = 10
        infoTextView.layer.borderWidth = 1
        infoTextView.layer.borderColor = UIColor.blue.cgColor
        infoTextView.clipsToBounds = true
    }
    
    //MARK:- Networking
    /*********************************/
    func getInfo(objectName: String)
    {
        SVProgressHUD.show()
        let parameters : [String : String] = ["format":"json",
                                              "action": "query",
                                              "prop": "extracts|pageimages",
                                              "exintro": "",
                                              "explaintext": "",
                                              "titles": objectName,
                                              "indexpageids": "",
                                              "redirects": "1",
                                              "pithumbsize": "500"]
        Alamofire.request(APIURL, method: .get, parameters: parameters).responseJSON
        { (response) in
            if response.result.isSuccess
            {
                print("\n\n\n\t\t\tSucess!\n\n\n")
                SVProgressHUD.showInfo(withStatus: "Information Retrieved, Enjoy ^^")
                let infoJSON : JSON = JSON(response.result.value!)
                print(infoJSON.debugDescription)
                
                //MARK:- JSON Parsing
                let pageid = infoJSON["query"]["pageids"][0].stringValue
                let objectDescription = infoJSON["query"]["pages"][pageid]["extract"].stringValue
                let objectImageURL = infoJSON["query"]["pages"][pageid]["thumbnail"]["source"].stringValue
                
                if(objectImageURL.count > 0 && objectDescription.count >= 20)
                {
                    self.imageTaken.sd_setImage(with: URL(string: objectImageURL))
                    self.infoTextView.text = objectDescription
                }
                else
                {
                    self.infoTextView.text = "well, it's Just a(n) \(objectName)"
                    
                }
                
            }
            else
            {
                print("\n\n\n\t\t\tFailure!\n\n\n")
                //TODO:- Display an error to the user
                self.infoTextView.text = "Connection Problems"
                
            }
        }
        SVProgressHUD.dismiss()
        
    }
    
    //MARK:- Formating userPickedImage into CIImage
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        cameraBtn.isEnabled = false
        SVProgressHUD.show()
        
        if let userPickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage
        {
            imageTaken.image = userPickedImage
            infoTextView.text = ""
            guard let ciimage = CIImage(image: userPickedImage) else
            {
                fatalError("Couldn't convert to CIImage.")
            }
            imagePicker.dismiss(animated: true, completion: nil)
            detect(image: ciimage)
            
        }
        
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    
    //MARK:- Detection Logic
    func detect(image : CIImage)
    {
        guard let model = try? VNCoreMLModel(for: Inceptionv3().model) else
        {
            fatalError("Loading CoreML Model Failed.") //if my model is nil , i am going to trigger the else with fatalError
        }
        
        let request = VNCoreMLRequest(model: model) { (request, error) in
            guard let results = request.results as? [VNClassificationObservation] else
            {
                fatalError("Model Failed to process the image")
            }
            print(results)
            DispatchQueue.main.async {
                self.cameraBtn.isEnabled = true
                SVProgressHUD.dismiss()
                
            }
            var firstResult = results.first?.identifier.capitalized
            if firstResult != nil
            {
                var commaIndex = firstResult?.index(of: ",")
                if commaIndex != nil
                {
                    firstResult = firstResult?.substring(to: commaIndex!)
                }
                self.navigationItem.title = "It's a \(String(describing: firstResult!))!"
                self.objectName = firstResult!
                self.infoTextView.text = "I can fetch you some info about this \(self.objectName) if you would like\nJust tap on the Get Info Button!"
                
            }
            else
            {
                firstResult = "Couldn't Identify this object"
                self.navigationItem.title = firstResult
            }
            
            
        }
        
        
        
        let handler = VNImageRequestHandler(ciImage: image)
        
        do {try handler.perform([request])} catch {print(error)}
    }
    
    
    //MARK:- IBActions
    @IBAction func cameraTapped(_ sender: UIBarButtonItem)
    {
        let alert = UIAlertController(title: "Notice", message: "Would you like to use the camera or pick an image from the albums?", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Use Camera ?", style: UIAlertActionStyle.default, handler: { (action) in
            self.imagePicker.sourceType = .camera
            self.present(self.imagePicker, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Use a Picture from the album?", style: UIAlertActionStyle.default, handler: { (action) in
            self.imagePicker.sourceType = .savedPhotosAlbum
            self.present(self.imagePicker, animated: true, completion: nil)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
        
        present(alert, animated: true, completion: nil)
        
    }
    
    
    @IBAction func getInfoBtnTapped(_ sender: Any)
    {
        if (self.imageTaken.image == #imageLiteral(resourceName: "placeholder"))
        {
            self.infoTextView.text = "you haven't selected or taken an Image !"
        }
        else
        {
            getInfo(objectName: self.objectName)
        }
    }
    
}
