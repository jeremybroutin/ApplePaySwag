//
//  DetailViewController.swift
//  ApplePaySwag
//
//  Created by Erik.Kerber on 10/17/14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

import UIKit
import PassKit

class BuySwagViewController: UIViewController {

  @IBOutlet weak var swagPriceLabel: UILabel!
  @IBOutlet weak var swagTitleLabel: UILabel!
  @IBOutlet weak var swagImage: UIImageView!
  @IBOutlet weak var applePayButton: UIButton!

  let SupportedPaymentNetworks = [PKPaymentNetworkVisa, PKPaymentNetworkMasterCard, PKPaymentNetworkAmex]
  let ApplePaySwagMerchantID = "merchant.com.jeremybroutin.ApplePaySwag"

  var swag: Swag! {
    didSet {
      // Update the view.
      self.configureView()
    }
  }

  func configureView() {

    if (!self.isViewLoaded()) {
      return
    }

    self.title = swag.title
    self.swagPriceLabel.text = "$" + swag.priceString
    self.swagImage.image = swag.image
    self.swagTitleLabel.text = swag.description
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.configureView()

    // Hide payment button if the user is unable to make payments (vs. the supported options)
    applePayButton.hidden = !PKPaymentAuthorizationViewController.canMakePaymentsUsingNetworks(SupportedPaymentNetworks)
  }

  @IBAction func purchase(sender: UIButton) {
    // Create payment request
    let request = PKPaymentRequest()

    // Populate PKPaymentRequest
    request.merchantIdentifier = ApplePaySwagMerchantID
    request.supportedNetworks = SupportedPaymentNetworks
    request.merchantCapabilities = PKMerchantCapability.Capability3DS //security standard (3DS is the most popular standard in the US)
    request.countryCode = "US"
    request.currencyCode = "USD"

    //Handling shipping, billing and contact info
    switch (swag.swagType){
    case .Delivered( _):
      var shippingMethods = [PKShippingMethod]()

      for shippingMethod in ShippingMethod.ShippingMethodOptions {
        let method = PKShippingMethod(label: shippingMethod.title, amount: shippingMethod.price)
        method.identifier = shippingMethod.title
        method.detail = shippingMethod.description
        shippingMethods.append(method)
      }

      request.shippingMethods = shippingMethods
    case .Electronic:
      break
    }

    // Add item and shipping cost
    request.paymentSummaryItems = calculateSummaryItemsFromSwag(swag)

    let applePayController = PKPaymentAuthorizationViewController(paymentRequest: request)
    applePayController.delegate = self // apply delegate available in extension
    self.presentViewController(applePayController, animated: true, completion: nil)
  }

  // Helper function to move all data from an ABRecord into the Address struct
  // Check out tutorial about Address Book here: https://www.raywenderlich.com/63885/address-book-tutorial-in-ios
  func createShippingAddressFromRef(address: ABRecord!) -> Address {
    var shippingAddress: Address = Address()
    shippingAddress.FirstName = ABRecordCopyValue(address, kABPersonFirstNameProperty)?.takeUnretainedValue() as? String
    shippingAddress.LastName = ABRecordCopyValue(address, kABPersonLastNameProperty)?.takeUnretainedValue() as? String

    let addressProperty: ABMultiValueRef = ABRecordCopyValue(address, kABPersonAddressProperty).takeUnretainedValue() as ABMultiValueRef
    if let dict: NSDictionary = ABMultiValueCopyValueAtIndex(addressProperty, 0).takeUnretainedValue() as? NSDictionary {
      shippingAddress.Street = dict[String(kABPersonAddressStreetKey)] as? String
      shippingAddress.City = dict[String(kABPersonAddressCityKey)] as? String
      shippingAddress.State = dict[String(kABPersonAddressStateKey)] as? String
      shippingAddress.Zip = dict[String(kABPersonAddressZIPKey)] as? String
    }

    return shippingAddress
  }

  // Helper function to builds the summary items
  func calculateSummaryItemsFromSwag(swag: Swag) -> [PKPaymentSummaryItem]{
    var summaryItems = [PKPaymentSummaryItem]()
    summaryItems.append(PKPaymentSummaryItem(label: swag.title, amount: swag.price))

    switch (swag.swagType){
    case .Delivered(let method):
      summaryItems.append(PKPaymentSummaryItem(label: "Shipping", amount: method.price))
    case .Electronic:
      break
    }

    summaryItems.append(PKPaymentSummaryItem(label: "Razeware", amount: swag.total()))

    return summaryItems
  }
}

extension BuySwagViewController: PKPaymentAuthorizationViewControllerDelegate{

  // Note: The PKPayment objects hold the Apple Pay authorization token, as well as shipping, billing and contact info for the order

  // Handle user authorization to complete process
  func paymentAuthorizationViewController(controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: (PKPaymentAuthorizationStatus) -> Void) {
    // TODO: Send payment request to backend for processing
    // For now, simply hardcoding the completion block
    completion(PKPaymentAuthorizationStatus.Success)
  }

  // Close the payment view controller once the request is completed
  func paymentAuthorizationViewControllerDidFinish(controller: PKPaymentAuthorizationViewController) {
    // Reset swagType to default shipping method
    swag.swagType = SwagType.Delivered(method: ShippingMethod.ShippingMethodOptions.first!)
    // Dismiss payment view
    controller.dismissViewControllerAnimated(true, completion: nil)
  }

  // Respond to changes in the shipping address
  func paymentAuthorizationViewController(controller: PKPaymentAuthorizationViewController, didSelectShippingAddress address: ABRecord, completion: (PKPaymentAuthorizationStatus, [PKShippingMethod], [PKPaymentSummaryItem]) -> Void) {
    // TODO: Might a service call to calculate sale stax, determine if we can ship at this address or verify if the address exists
    let shippingAddress = createShippingAddressFromRef(address)

    // Test wether the city, state and zip values are valid
    switch (shippingAddress.State, shippingAddress.City, shippingAddress.Zip){
    case (.Some( _), .Some( _), .Some( _)):
      print("Payment made")
      completion(PKPaymentAuthorizationStatus.Success, [], [])
    default:
      completion(PKPaymentAuthorizationStatus.InvalidShippingPostalAddress, [], [])
    }
  }

  // Respond to changes in the shipping methods
  func paymentAuthorizationViewController(controller: PKPaymentAuthorizationViewController, didSelectShippingMethod shippingMethod: PKShippingMethod, completion: (PKPaymentAuthorizationStatus, [PKPaymentSummaryItem]) -> Void) {
    let shippingMethod = ShippingMethod.ShippingMethodOptions.filter {(method) in method.title == shippingMethod.identifier}.first!
    swag.swagType = SwagType.Delivered(method: shippingMethod)
    completion(PKPaymentAuthorizationStatus.Success, calculateSummaryItemsFromSwag(swag))
  }
}

