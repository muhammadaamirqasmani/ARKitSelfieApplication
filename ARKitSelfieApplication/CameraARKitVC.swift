//
//  ARKitVC.swift
//  ARKitSelfieApplication
//
//  Created by admin on 29/11/2017.
//  Copyright © 2017 MuhammadAamir. All rights reserved.
//

import UIKit
import ARKit
import ARVideoKit
import Photos


class CameraARKitVC: UIViewController, ARSCNViewDelegate, RenderARDelegate, RecordARDelegate, UICollectionViewDataSource , UICollectionViewDelegate{


    

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var modelCollection: UICollectionView!
    
    let caprturingQueue = DispatchQueue(label: "capturingThread", attributes: .concurrent)
    var recorder:RecordAR?
    let itemsArray: [String] = ["goku","cup", "vase", "boxing", "table"]
    var selectedItem: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        
        self.sceneView.delegate = self
        
        modelCollection.delegate = self
        modelCollection.dataSource = self
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/goku.scn")!
        // Set the scene to the view
        sceneView.scene = scene
        sceneView.scene.rootNode.scale = SCNVector3(0.2, 0.2, 0.2)

//         Initialize ARVideoKit recorder
        recorder = RecordAR(ARSceneKit: sceneView)

        // Set the recorder's delegate
        recorder?.delegate = self

        // Set the renderer's delegate
        recorder?.renderAR = self

        // Configure the renderer to perform additional image & video processing 👁
        recorder?.onlyRenderWhileRecording = false

        // Configure ARKit content mode. Default is .auto
        //recorder?.contentMode = .aspectFit

        // Set the UIViewController orientations
        recorder?.inputViewOrientations = [.landscapeLeft, .landscapeRight, .portrait]

        // Configure RecordAR to store media files in local app directory
        recorder?.deleteCacheWhenExported = false
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        // Run the view's session
        sceneView.session.run(configuration)
        
        // Prepare the recorder with sessions configuration
//        recorder?.prepare(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return itemsArray.count
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ModelCell", for: indexPath) as! ModelCell
        cell.modelImage.image = UIImage(named: "\(self.itemsArray[indexPath.row]).png")
        print("\(self.itemsArray[indexPath.row]).png")
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        self.selectedItem = itemsArray[indexPath.row]
        cell?.backgroundColor = UIColor.green
    }
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath)
        cell?.backgroundColor = UIColor.orange
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {return}
        
        let planeNode = createPlane(withPlaneAnchor: planeAnchor)
        
        node.addChildNode(planeNode)
    }
    
    func createPlane(withPlaneAnchor planeAnchor: ARPlaneAnchor) -> SCNNode {
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let planeNode = SCNNode()
        planeNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi/2, 1, 0, 0)
        let gridMaterial = SCNMaterial()
        gridMaterial.diffuse.contents = UIImage(named: "art.scnassets/grid.png")
        plane.materials = [gridMaterial]
        planeNode.geometry = plane
        
        return planeNode
    }
    
    // MARK: - Hide Status Bar
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Exported UIAlert present method
    func exportMessage(success: Bool, status:PHAuthorizationStatus) {
        if success {
            let alert = UIAlertController(title: "Exported", message: "Media exported to camera roll successfully!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Awesome", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }else if status == .denied || status == .restricted || status == .notDetermined {
            let errorView = UIAlertController(title: "😅", message: "Please allow access to the photo library in order to save this media file.", preferredStyle: .alert)
            let settingsBtn = UIAlertAction(title: "Open Settings", style: .cancel) { (_) -> Void in
                guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString) else {
                    return
                }
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    if #available(iOS 10.0, *) {
                        UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        })
                    } else {
                        UIApplication.shared.openURL(URL(string:UIApplicationOpenSettingsURLString)!)
                    }
                }
            }
            errorView.addAction(UIAlertAction(title: "Later", style: UIAlertActionStyle.default, handler: {
                (UIAlertAction)in
            }))
            errorView.addAction(settingsBtn)
            self.present(errorView, animated: true, completion: nil)
        }else{
            let alert = UIAlertController(title: "Exporting Failed", message: "There was an error while exporting your media file.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }

    
    @IBAction func capture(_ sender: UIButton) {
        if sender.tag == 0 {
            //Photo
            if recorder?.status == .readyToRecord {
                let image = self.recorder?.photo()
                self.recorder?.export(UIImage: image) { saved, status in
                    if saved {
                        // Inform user photo has exported successfully
                        self.exportMessage(success: saved, status: status)
                    }
                }
            }
        }else if sender.tag == 1 {
            //Live Photo
            if recorder?.status == .readyToRecord {
                caprturingQueue.async {
                    self.recorder?.livePhoto(export: true) { ready, photo, status, saved in
                        /*
                         if ready {
                         // Do something with the `photo` (PHLivePhotoPlus)
                         }
                         */
                        
                        if saved {
                            // Inform user Live Photo has exported successfully
                            self.exportMessage(success: saved, status: status!)
                        }
                    }
                }
            }
        }else if sender.tag == 2 {
            //GIF
            if recorder?.status == .readyToRecord {
                recorder?.gif(forDuration: 3.0, export: true) { ready, gifPath, status, saved in
                    /*
                     if ready {
                     // Do something with the `gifPath`
                     }
                     */
                    
                    if saved {
                        // Inform user GIF image has exported successfully
                        self.exportMessage(success: saved, status: status!)
                    }
                }
            }
        }
    }
    
    func frame(didRender buffer: CVPixelBuffer, with time: CMTime, using rawBuffer: CVPixelBuffer) {
        // Do some image/video processing.
    }
    
    func recorder(didEndRecording path: URL, with noError: Bool) {
        if noError {
            // Do something with the video path.
        }
    }
    
    func recorder(didFailRecording error: Error?, and status: String) {
        // Inform user an error occurred while recording.
    }
    
    func recorder(willEnterBackground status: RecordARStatus) {
        // Use this method to pause or stop video recording. Check [applicationWillResignActive(_:)](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622950-applicationwillresignactive) for more information.
        if status == .recording {
            recorder?.stopAndExport()
        }
    }
    
    
}


