//
//  AddressBarSearchDelegate.swift
//  Reynard
//
//  Created by Minh Ton on 21/6/26.
//

protocol AddressBarSearchDelegate: AnyObject {
    func addressBarDidSubmit(_ searchTerm: String)
    func addressBarDidTapDismiss(_ addressBar: AddressBar)
    func addressBarDidBeginEditing(_ addressBar: AddressBar)
    func addressBarDidEndEditing(_ addressBar: AddressBar)
    func addressBar(_ addressBar: AddressBar, didChangeText text: String, previousText: String, isDelete: Bool)
}
