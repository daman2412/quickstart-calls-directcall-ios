//
//  CallHistoryViewController.swift
//  QuickStart
//
//  Created by Jaesung Lee on 2020/04/29.
//  Copyright © 2020 SendBird Inc. All rights reserved.
//

import UIKit
import SendBirdCalls

class CallHistoryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noHistoryIcon: UIImageView!
    @IBOutlet weak var noHistoryLabel: UILabel!
    
    var query: DirectCallLogListQuery?
    var callLogs: [DirectCallLog] {
        get { UserDefaults.standard.callLogs }
        set {
            self.tableView.isHidden = newValue.isEmpty
            self.noHistoryIcon.isHidden = !newValue.isEmpty
            self.noHistoryLabel.isHidden = !newValue.isEmpty
        }
    }
    
    let indicator = UIActivityIndicatorView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.delegate = self
        self.tableView.dataSource = self
        
        self.navigationItem.title = "Call History"
        
        // query
        let params = DirectCallLogListQuery.Params()
        params.limit = 100
        self.query = SendBirdCall.createDirectCallLogListQuery(with: params)
        
        guard self.callLogs.isEmpty else {
            self.tableView.reloadData()
            return
        }
        
        self.tableView.isHidden = true
        self.indicator.startLoading(on: self.view)
        self.fetchCallLogsFromServer()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.callLogs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "directCallLogCell", for: indexPath) as! CallHistoryTableViewCell
        cell.delegate = self
        cell.directCallLog = self.callLogs[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        
        
    }
    
    func fetchCallLogsFromServer() {
        self.query?.next { callLogs, error in
            guard let newCallLogs = callLogs, !newCallLogs.isEmpty else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.presentAlert(message: "Loaded all call logs from server successfully.")
                    self.indicator.stopLoading()
                }
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Update callLogs
                let previousLogs = NSMutableOrderedSet(array: self.callLogs)
                let newLogs = NSMutableOrderedSet(array: newCallLogs)
                previousLogs.union(newLogs)
                guard let updatedLogs = previousLogs.array as? [DirectCallLog] else { return }
                self.callLogs = updatedLogs
                
                self.updateCallHistories()
            }
            
            self.fetchCallLogsFromServer()
        }
    }
    
    func updateCallHistories() {
        self.tableView.reloadData()
        
        UserDefaults.standard.callLogs = self.callLogs
    }
}

// MARK: - SendBirdCall: Make a Call
extension CallHistoryViewController: CallHistoryCellDelegate {
    func didTapVoiceCallButton(_ cell: CallHistoryTableViewCell, dialParams: DialParams) {
        cell.voiceCallButton.isEnabled = false
        self.indicator.startLoading(on: self.view)
        
        SendBirdCall.dial(with: dialParams) { call, error in
            DispatchQueue.main.async { [weak self] in
                cell.voiceCallButton.isEnabled = true
                guard let self = self else { return }
                self.indicator.stopLoading()
            }
            
            guard let call = call, error == nil else {
                DispatchQueue.main.async {
                    UIApplication.shared.showError(with: error?.localizedDescription ?? "Failed to call with unknown error")
                }
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.showCallController(with: call)
            }
        }
    }
    
    func didTapVideoCallButton(_ cell: CallHistoryTableViewCell, dialParams: DialParams) {
        cell.videoCallButton.isEnabled = false
        self.indicator.startLoading(on: self.view)
        
        SendBirdCall.dial(with: dialParams) { call, error in
            DispatchQueue.main.async { [weak self] in
                cell.videoCallButton.isEnabled = true
                guard let self = self else { return }
                self.indicator.stopLoading()
            }
            
            guard let call = call, error == nil else {
                DispatchQueue.main.async {
                    UIApplication.shared.showError(with: error?.localizedDescription ?? "Failed to call with unknown error")
                }
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.showCallController(with: call)
            }
        }
    }
    
    func didTapCallHistoryCell(_ cell: CallHistoryTableViewCell) {
        guard let remoteUserID = cell.remoteUserIDLabel.text else { return }
        
        let dialParams = DialParams(calleeId: remoteUserID,
                                    isVideoCall: cell.directCallLog.isVideoCall,
                                    callOptions: CallOptions(isAudioEnabled: true,
                                                             isVideoEnabled: cell.directCallLog.isVideoCall,
                                                             localVideoView: nil,
                                                             remoteVideoView: nil,
                                                             useFrontCamera: true),
                                    customItems: [:])
        
        SendBirdCall.dial(with: dialParams) { call, error in
            DispatchQueue.main.async { [weak self] in
                cell.videoCallButton.isEnabled = true
                guard let self = self else { return }
                self.indicator.stopLoading()
            }
            
            guard let call = call, error == nil else {
                DispatchQueue.main.async {
                    UIApplication.shared.showError(with: error?.localizedDescription ?? "Failed to call with unknown error")
                }
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.showCallController(with: call)
            }
        }
    }
}

extension UIApplication {
    func showError(with message: String) {
        if let topViewController = UIViewController.topViewController {
            topViewController.presentErrorAlert(message: message)
        } else {
            UIApplication.shared.keyWindow?.rootViewController?.presentErrorAlert(message: message)
            UIApplication.shared.keyWindow?.makeKeyAndVisible()
        }
    }
    
    func showCallController(with call: DirectCall) {
        // If there is termination: Failed to load VoiceCallViewController from Main.storyboard. Please check its storyboard ID")
        let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: call.isVideoCall ? "VideoCallViewController" : "VoiceCallViewController")
        
        if var dataSource = viewController as? DirectCallDataSource {
            dataSource.call = call
            dataSource.isDialing = false
        }
        
        if let topViewController = UIViewController.topViewController {
            topViewController.present(viewController, animated: true, completion: nil)
        } else {
            self.keyWindow?.rootViewController = viewController
            self.keyWindow?.makeKeyAndVisible()
        }
    }
}
