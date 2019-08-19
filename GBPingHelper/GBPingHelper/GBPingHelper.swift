//
//  GBPingHelper.swift
//  GBPingHelper
//
//  Created by kETAN on 19/08/19.
//  Copyright © 2019 Tushar Sanchaniya. All rights reserved.
//

import Foundation

public protocol GBPingHelperDelegate  {
    func numberOfPacketSent(_ iCounter : Int)
    func numberOfPacketReceived(_ iCounter : Int, _ estimateTime : String)
    func numberOfPacketFailed(_ iCounter : Int, _ percentage : Double)
    func calculateJitterAverage(_ jitterValue : Double)
}


public class GBPingHelper : NSObject {
    
    fileprivate let objGPing = GBPing()
    
    fileprivate var stopPingingimer : Int!
    
    fileprivate var iSendPacketCount : Int = 0
    fileprivate var iReceivePacketCount : Int = 0
    fileprivate var iFailedPacketCount : Int = 0
    
    
    fileprivate var arrJitter : [Double]!
    
    public static let shared = GBPingHelper()
    public var delegate : GBPingHelperDelegate?
    
    public func startGBPingProcess(_ url : String) {
        
        objGPing.host = url
        objGPing.delegate = self
        arrJitter = [Double]()
        objGPing.setup { (bPingStatus, error) in
            
            if bPingStatus {
                self.objGPing.startPinging()
                if self.stopPingingimer != nil {
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(self.stopPingingimer), execute: {
                        self.objGPing.stop()
                        self.iSendPacketCount = 0
                        self.iReceivePacketCount = 0
                        self.iFailedPacketCount = 0
                    })
                }
            }
            else {
                if error != nil {
                    self.printDebug("Failed to Start Ping service : \(error?.localizedDescription ?? "ERROR NOT DESCRIBE")")
                }
                else {
                    self.printDebug("Failed to Start Ping service.")
                }
            }
        }
    }
    
    public func setMaxPingValue(_ newTimeValue :Int) {
        stopPingingimer = newTimeValue
    }
    
    public func stopPingProcess() {
        objGPing.stop()
    }
    
    @discardableResult public func isPingging() -> Bool {
        return objGPing.isPinging
    }
    
    internal func printDebug(_ log : Any, _ debugFile : String? = #file, _ debugLine : Int? = #line, _ debugFunction : String? = #function) {
        
        let completeLogMsg = "[\(debugFile?.components(separatedBy: "/").last!.components(separatedBy: ".").first! ?? ""):\(debugLine ?? 0) > \(debugFunction ?? "")] \(log)"
        
        print("\(completeLogMsg)")
        
    }
    
}

extension GBPingHelper : GBPingDelegate {
    
    fileprivate func ping(_ pinger: GBPing, didSendPingWith summary: GBPingSummary) {
        iSendPacketCount+=1
        //printDebug(">>> Send Date: \(summary.sendDate!),  PayloadSize: \(summary.payloadSize), TTL :\(summary.ttl)")
        if delegate != nil {
            delegate?.numberOfPacketSent(iSendPacketCount)
        }
    }
    
    fileprivate func ping(_ pinger: GBPing, didTimeoutWith summary: GBPingSummary) {
        if summary.receiveDate != nil {
            //printDebug(">>> Send Date: \(summary.sendDate), Receive Date: \(summary.receiveDate), PayloadSize: \(summary.payloadSize), TTL :\(summary.ttl)")
        }
        else {
            //printDebug(">>> Send Date: \(summary.sendDate), PayloadSize: \(summary.payloadSize), TTL :\(summary.ttl)")
        }
    }
    
    fileprivate func ping(_ pinger: GBPing, didReceiveReplyWith summary: GBPingSummary) {
        
        //AndsfUtility.printDebug(">>> Send Date: \(summary.receiveDate!),  PayloadSize: \(summary.payloadSize), TTL :\(summary.ttl)")
        iReceivePacketCount+=1
        let iSendDateIntervale = summary.sendDate?.timeIntervalSinceReferenceDate
        let iReceiveDateIntervale = summary.receiveDate?.timeIntervalSinceReferenceDate
        
        if delegate != nil {
            arrJitter.append(Double(iReceiveDateIntervale! - iSendDateIntervale!))
            
            let iArrayElementSum = arrJitter.reduce(0, +)
            let avgCount = Double(iArrayElementSum/Double(arrJitter.count)).rounded(digits: 2)
            delegate?.calculateJitterAverage(avgCount)
            
            delegate?.numberOfPacketReceived(iReceivePacketCount, "\(String(format: "%.2f ms", Double(iReceiveDateIntervale! - iSendDateIntervale!)))")
        }
    }
    
    fileprivate func ping(_ pinger: GBPing, didReceiveUnexpectedReplyWith summary: GBPingSummary) {
        //printDebug(">>> TTL: \(summary.ttl) , Host: \(summary.host)")
    }
    
    fileprivate func ping(_ pinger: GBPing, didFailWithError error: Error) {
        iFailedPacketCount+=1
        printDebug(">>> \(error.localizedDescription)")
        if delegate != nil {
            //Packet loss in Percentage
            /*
             *   Example:
             *   Num. of package                         %tage
             *          42                                100
             *          41(Received + failed)              ?
             *
             *          100 - (4100/42)
             *              2.38 %
             *
             */
            
            var average : Double = 100
            
            if iReceivePacketCount > 0 {
                average = 100 - Double(((iReceivePacketCount + iFailedPacketCount)*100)/iSendPacketCount)
            }
            delegate?.numberOfPacketFailed(iFailedPacketCount, average)
            
        }
    }
    
}

fileprivate extension Double {
    func rounded(digits: Int) -> Double {
        let multiplier = pow(10.0, Double(digits))
        return (self * multiplier).rounded() / multiplier
    }
}
