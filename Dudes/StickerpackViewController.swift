//
//  StickerpackViewController.swift
//  Dudes
//
//  Created by Anton Evstigneev on 16.12.2020.
//

import UIKit
import CoreData
import Foundation
import Messages
import MessageUI

class StickerpackViewController: UIViewController, UICollectionViewDelegate {
    
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    enum Section {
        case dudes
    }
    
    var stickerpack: Stickerpack!
    var newDudes: [Dude] = []
    var dudes: [Dude] = []
    var dudesCollectionView: UICollectionView!
    var dudesDataSource: UICollectionViewDiffableDataSource<Section, Dude>!
    var dudesSnapshot: NSDiffableDataSourceSnapshot<Section, Dude>!
    var selectedDudes = Set<Dude>()
    var selectedCells = Set<IndexPath>()
    
    @IBOutlet weak var emptyStateView: UIStackView!
    @IBOutlet weak var shareStickerpackButton: UIButton!
    @IBAction func shareStickerpack(_ sender: UIButton) {
//        saveStickerpack()
//        (UserDefaults.standard.value(forKey: "isFirstLaunch") as! Bool) ? showExplanataryAlert() : showAlert("SAVED!")
//        UserDefaults.standard.setValue(false, forKey: "isFirstLaunch")
        
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for messenger in Messenger.allCases {
            let actionAlert: UIAlertAction = UIAlertAction(title: messenger.rawValue, style: .default) { action in
                // Sharing action here
                print(messenger.rawValue)
            }
            controller.addAction(actionAlert)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        cancelAction.setValue(UIColor.lightGray, forKey: "titleTextColor")
        
        controller.addAction(cancelAction)
        controller.view.subviews.first?.subviews.first?.subviews.first?.backgroundColor = UIColor(named: "ActionSheet")
        controller.view.tintColor = UIColor(named: "AccentColor")
        
        self.present(controller, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureHierarchy()
        configureDataSource()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        setupNavigationItems()
    }
    
    @objc func showEditMenu() {
        navigationItem.title = "0 SELECTED"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "CANCEL", style: .plain, target: self, action: #selector(cancelStickerpackChanges))
        navigationItem.rightBarButtonItem!.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : UIColor(named: "AccentColor")!], for: .normal)
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "DELETE", style: .plain, target: self, action: #selector(deleteStickers))
        navigationItem.leftBarButtonItem!.setTitleTextAttributes([NSAttributedString.Key.foregroundColor : UIColor(named: "AccentColor")!], for: .normal)
        if selectedDudes.isEmpty {
            navigationItem.leftBarButtonItem!.isEnabled = false
        }
    }
    
    @objc func deleteStickers() {
        let actionTitle = "Selected stickers will be deleted from stickerpack."
        showActionAlert(title: actionTitle, message: "", confirmation: "Delete", success: { [self] () -> Void in
            for indexPath in selectedCells.sorted(by: >) {
                dudes.remove(at: indexPath.row)
            }
            for case let sticker as Sticker in stickerpack.stickers! {
                if selectedDudes.map({ $0.id }).contains(sticker.id) {
                    context.delete(sticker)
                }
            }
            stickerpack.isInUpdateMode = true
            (UIApplication.shared.delegate as! AppDelegate).saveContext()
            applyDataSnapshot()
            cancelStickerpackChanges()
        }) { [self] () -> Void in
            cancelStickerpackChanges()
        }
    }
    
    @objc func cancelStickerpackChanges() {
        dudesCollectionView.deselectAllItems()
        selectedCells = []
        selectedDudes = []
        let image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(weight: .medium))
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(addStickers))
        navigationItem.leftBarButtonItem = nil
        navigationItem.title = ""
    }
    
    @objc func addStickers() {
        self.performSegue(withIdentifier: "DudesViewController", sender: (Any).self)
    }
    
    func stickerpackUpdated() {
        stickerpack.isInUpdateMode = false
        (UIApplication.shared.delegate as! AppDelegate).saveContext()
    }
}



// MARK: - Prepare for segue
extension StickerpackViewController {
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destinationVC = segue.destination as? DudesViewController {
            self.stickerpack.isInUpdateMode = true
            destinationVC.dudesBeforeUpdate = self.dudes
            destinationVC.stickerpack = self.stickerpack
            destinationVC.selectedDudesLimit = 99 - self.dudes.count
        }
    }
}



// MARK: - Stickerpack saving method
extension StickerpackViewController {
    func saveStickerpack() {
        // populate stickerpack with stickers
        var dudesToSave: [Dude] = []
        if stickerpack.isInUpdateMode == true {
            dudesToSave = self.newDudes
        } else {
            dudesToSave = self.dudes
        }
        for dude in dudesToSave {
            let sticker = Sticker(context: context)
            sticker.emotion = dude.emotion
            sticker.image = dude.image
            sticker.id = dude.id
            sticker.timestamp = dude.timestamp
            sticker.stickerpack = stickerpack
        }
        
        stickerpack.isInUpdateMode = true
        (UIApplication.shared.delegate as! AppDelegate).saveContext()
    }
}



// MARK: - CollectionView layout
extension StickerpackViewController {
    func createDudesLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(120),
                                             heightDimension: .absolute(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .absolute(120))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: 3)
        let spacing = CGFloat(10)
        group.interItemSpacing = .fixed(spacing)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 10, bottom: 0, trailing: 10)
  
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }
}



// MARK: - CollectionView dataSource
extension StickerpackViewController {
    func configureHierarchy() {
        dudesCollectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height), collectionViewLayout: createDudesLayout())
        dudesCollectionView.delegate = self
        dudesCollectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dudesCollectionView.backgroundColor = .black
        dudesCollectionView.allowsMultipleSelection = true
        dudesCollectionView.showsVerticalScrollIndicator = false
        view.addSubview(dudesCollectionView)
        view.bringSubviewToFront(shareStickerpackButton)
    }
    
    func configureDataSource() {
        let dudeCellRegistration = UICollectionView.CellRegistration
        <DudeCell, Dude> { (cell, indexPath, dude) in
            cell.imageView.image = UIImage(data: dude.image)
        }
        
        dudesDataSource = UICollectionViewDiffableDataSource<Section, Dude>(collectionView: dudesCollectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, identifier: Dude) -> UICollectionViewCell? in
            
            return collectionView.dequeueConfiguredReusableCell(using: dudeCellRegistration, for: indexPath, item: identifier)
        }
        
        applyDataSnapshot()
    }
    
    private func applyDataSnapshot() {
        DispatchQueue.main.async() { [self] in
            dudesSnapshot = NSDiffableDataSourceSnapshot<Section, Dude>()
            dudesSnapshot.appendSections([.dudes])
            dudesSnapshot.appendItems(dudes)
            dudesDataSource.apply(dudesSnapshot, animatingDifferences: true)
            
            if dudes.isEmpty {
                view.bringSubviewToFront(emptyStateView)
                emptyStateView.isHidden = false
                shareStickerpackButton.isHidden = true
            } else {
                emptyStateView.isHidden = true
            }
        }
    }
}



// MARK: - CollectionView Selection
extension StickerpackViewController {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedCells.insert(indexPath)
        let selectedDude = dudesDataSource.itemIdentifier(for: indexPath)
        selectedDudes.insert(selectedDude!)
        showEditMenu()
        if !selectedDudes.isEmpty {
            navigationItem.title = "\(selectedDudes.count) SELECTED"
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        selectedCells.remove(indexPath)
        let deselectedDude = dudesDataSource.itemIdentifier(for: indexPath)
        selectedDudes.remove(deselectedDude!)
        navigationItem.title = "\(selectedDudes.count) SELECTED"
        showEditMenu()
        if !selectedDudes.isEmpty {
            navigationItem.title = "\(selectedDudes.count) SELECTED"
        } else {
            navigationItem.title = ""
            cancelStickerpackChanges()
        }
    }
}



// MARK: - NavigationBar setup
extension StickerpackViewController {
    func setupNavigationItems() {
        let image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(weight: .medium))
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(addStickers))
        navigationController?.navigationBar.tintColor = UIColor(named: "AccentColor")!
        navigationController?.hidesBarsOnSwipe = false
        navigationController?.isNavigationBarHidden = false
    }
}



// MARK: - Telegram export
extension StickerpackViewController {
    func exportToTelegram() {
        let dudesImages = dudes.map { UIImage(data: $0.image)!.convertToString() }
        let emojis = self.dudes.map { $0.emotion }
        let id = stickerpack.id!

        postRequest(id: id, emojis: emojis, dudes: dudesImages) { (success, error) in
            DispatchQueue.main.async() { [self] in
            removeSpinner()
            if success {
                let botURL = URL.init(string: "tg://resolve?domain=DudesStickersBot?start=\(stickerpack.id!)")

                if UIApplication.shared.canOpenURL(botURL!) {
                    UIApplication.shared.open(botURL!)
                } else {
                    showAlert("Telegram is not installed",
                              "To export stickerpack for Telegram the Telegram app must be installed.")
                }
            } else {
                    showAlert("Stickerpack request failed", "Please try again later.")
                }
            }
        }
    }
}
