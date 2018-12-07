//
//  FavoriteVC.swift
//  RecipeFlicker
//
//  Created by minami on 2018-10-16.
//  Copyright © 2018 Kenta Kodashima. All rights reserved.
//

import UIKit
import Firebase
import RealmSwift

class FavoriteVC: UIViewController {
  
  enum ViewType: Int {
    case list
    case grid
  }
  
  var ref: DatabaseReference!
  var userID: String!
  var selectedCollectionId: String!
  var selectedRecipeId: String?
  
  @IBOutlet weak var typeSegmentControll: UISegmentedControl!
  @IBOutlet weak var collectionView: UICollectionView!
  @IBOutlet weak var searchBar: UISearchBar!
  @IBOutlet weak var toolBar: UIToolbar!
  
  let gridLayout = GridFlowLayout()
  let listLayout = ListFlowLayout()
  
  let recipeFactory = ReplicaRecipeFactory()
  var favoriteRecipes = [Recipe]()
  var collections = [Collection]()
  var isAddToMode = false
  var addToView: UIView!
  var indexPathsOfSelectedItems: [Int]?
  
  fileprivate func getFavoriteRecipesFromFirebase(_ userID: String?) {
    ref.child("favorites").child(userID!).observe(.value) { (snapshot) in
      self.favoriteRecipes.removeAll()
      for child in snapshot.children {
        if let recipe = (child as! DataSnapshot).value as? [String: Any]
        {
          
          let id = recipe["firebaseId"] as! String
          let url = recipe["originalRecipeUrl"] as! String
          let title = recipe["title"] as! String
          let image = recipe["image"] as! String
          let isFavotiteLiteral = recipe["isFavorite"]  as! String
          let whichCollectionToBelongList = List<String>()
          if let whichCollectionToBelong = recipe["whichCollectionToBelong"] {
            for collectionId in whichCollectionToBelong as! NSArray {
              whichCollectionToBelongList.append(collectionId as! String)
            }
          }
          let favoriteRecipe = Recipe(firebaseId: id, originalRecipeUrl: url, title: title, image: image, isFavorite: (isFavotiteLiteral == "true"), whichCollectionToBelong: whichCollectionToBelongList)
          self.favoriteRecipes.append(favoriteRecipe)
        }
      }
      if self.typeSegmentControll.selectedSegmentIndex == ViewType.list.rawValue
        && self.favoriteRecipes.count <= 0 {
        self.collectionView.setNoDataLabelForCollectionView()
      } else {
        self.collectionView.removeNoDataLabel()
      }
      self.collectionView.reloadData()
    }
  }
  
  fileprivate func getCollectionsFromFirebase(_ userID: String?) {
    ref.child("userCollections").child(userID!).observe(.value) { (snapshot) in
      self.collections.removeAll()
      for child in snapshot.children {
        if let collectionData = (child as! DataSnapshot).value as? [String: String],
        let id = collectionData["firebaseId"],
        let name = collectionData["name"]
        {
          let image = collectionData["image"]
          let collection = Collection(withId: id, andName: name, andImageUrl: image)
          self.collections.append(collection)
        }
      }
      if self.typeSegmentControll.selectedSegmentIndex == ViewType.grid.rawValue
        && self.collections.count <= 0 {
        self.collectionView.setNoDataLabelForCollectionView()
      } else {
        self.collectionView.removeNoDataLabel()
      }
      self.collectionView.reloadData()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    searchBar.setSearchBar()
    
    ref = Database.database().reference()
    userID = Auth.auth().currentUser?.uid
    
    getFavoriteRecipesFromFirebase(userID)
    getCollectionsFromFirebase(userID)
    
    typeSegmentControll.tintColor = AppColors.accent.value
    collectionView.collectionViewLayout = listLayout
    collectionView.register(CollectionViewCellForList.self,
                            forCellWithReuseIdentifier: CollectionViewCellForList.reuseIdentifier)
    collectionView.register(CollectionViewCellForGrid.self, forCellWithReuseIdentifier: CollectionViewCellForGrid.reuseIdentifier)
    
    navigationItem.leftBarButtonItem = editButtonItem
    // isEditing
    // override func setEditing(_ editing: Bool, animated: Bool)
    toolBar.isHidden = true
    
    // CollectionView
    addToView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))
  }
  
  @IBAction func onSegmentControlTapped(_ sender: UISegmentedControl) {
    switch sender.selectedSegmentIndex {
    case ViewType.list.rawValue:
      navigationItem.leftBarButtonItem = editButtonItem
      changeView(flowLayout: listLayout)
      if favoriteRecipes.count <= 0 {
        collectionView.setNoDataLabelForCollectionView()
      }
      break
    case ViewType.grid.rawValue:
      changeView(flowLayout: gridLayout)
      isEditing = false
      navigationItem.leftBarButtonItem = nil
      if collections.count <= 0 {
       collectionView.setNoDataLabelForCollectionView()
      }
      break
    default:
      break
    }
  }
  
  func changeView(flowLayout: UICollectionViewFlowLayout) {
    self.collectionView.removeNoDataLabel()
    self.collectionView.collectionViewLayout.invalidateLayout()
    if isEditing {
      let indexPaths = collectionView.indexPathsForVisibleItems
      for indexPath in indexPaths {
        let cell = collectionView.cellForItem(at: indexPath) as! CollectionViewCellForList
        cell.checkBoxImage.isHidden = true
      }
    }
    self.collectionView.reloadData()
    self.collectionView.setCollectionViewLayout(flowLayout, animated: false)

  }
  
  override func setEditing(_ editing: Bool, animated: Bool) {
    super.setEditing(editing, animated: animated)
    collectionView.reloadData()
    collectionView.allowsMultipleSelection = true
    if editing {
      self.editButtonItem.title = "Cancel"
    } else {
      self.toolBar.isHidden = true
      isAddToMode = false
      toggleCollectionView()
    }

  }
  @IBAction func addTo(_ sender: UIBarButtonItem) {
    guard let indexPaths = collectionView.indexPathsForSelectedItems else { return }
    indexPathsOfSelectedItems = indexPaths.map { $0.item }.sorted().reversed()
    print("indexPaths: \(indexPathsOfSelectedItems)")
    isAddToMode = true
    toggleCollectionView()
  }
  
  func toggleCollectionView() {
    if isAddToMode {
      self.view.addSubview(addToView)
      let addToCollectionView = UICollectionView(frame: addToView.frame, collectionViewLayout: gridLayout)
      addToCollectionView.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
      addToCollectionView.delegate = self
      addToCollectionView.dataSource = self
      addToCollectionView.register(CollectionViewCellForGrid.self, forCellWithReuseIdentifier: CollectionViewCellForGrid.reuseIdentifier)
      addToView.addSubview(addToCollectionView)
    } else {
      self.addToView.removeFromSuperview()
    }

  }
  
  @IBAction func deleteItems(_ sender: UIBarButtonItem) {
    // update model
    if let indexPaths = collectionView.indexPathsForSelectedItems {
      let indices = indexPaths.map { $0.item }.sorted().reversed()
      for index in indices {
        deleteItemFromFirebase(recipe: favoriteRecipes[index])
        favoriteRecipes.remove(at: index)
      }
      // update collectionView
      collectionView.deleteItems(at: indexPaths)
    }
    // dismiss the toolbar
    toolBar.isHidden = true
  }
  
  func deleteItemFromFirebase(recipe: Recipe) {
    // Delete items from favorite
    ref.child("favorites").child(userID).child(recipe.firebaseId).removeValue()
    // Delete items from collections
    for collectionId in recipe.whichCollectionToBelong {
      let ref = Database.database().reference()
      ref.child("recipeCollections/\(collectionId)/\(recipe.firebaseId)").removeValue()
      checkIfCollectionIsEmpty(collectionId: collectionId)
    }
  }
  
  func checkIfCollectionIsEmpty(collectionId: String) {
    ref.child("recipeCollections").child(collectionId).observe(.value) { (snapshot) in
      if !snapshot.exists() {
        self.ref.child("userCollections").child(self.userID!).child(collectionId).removeValue()
      }
    }
  }
  
}

extension FavoriteVC: UICollectionViewDataSource, UICollectionViewDelegate {
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    if typeSegmentControll.selectedSegmentIndex == ViewType.grid.rawValue || isAddToMode {
      if collections.count > 0 {
        return collections.count
      } else {
        return 0
      }

    } else {
      if favoriteRecipes.count > 0 {
        return favoriteRecipes.count
      } else {
        return 0
      }

    }
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    if typeSegmentControll.selectedSegmentIndex == ViewType.grid.rawValue || isAddToMode {
      let collection = collections[indexPath.row]
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: CollectionViewCellForGrid.reuseIdentifier,
        for: indexPath)
        as! CollectionViewCellForGrid
      cell.setupContents(withTitle: collection.name, andImage: collection.image ?? "")
      return cell
    } else
    //if typeSegmentControll.selectedSegmentIndex == ViewType.list.rawValue
    {
      let recipe = favoriteRecipes[indexPath.row]
      let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: CollectionViewCellForList.reuseIdentifier,
        for: indexPath)
        as! CollectionViewCellForList
      cell.setupContents(withTitle: recipe.title, andImage: recipe.image)
      cell.toggleEditMode(isEditing: isEditing)
      return cell
    } //else {
//      let collection = collections[indexPath.row]
//      let cell = collectionView.dequeueReusableCell(
//        withReuseIdentifier: CollectionViewCellForGrid.reuseIdentifier,
//        for: indexPath)
//        as! CollectionViewCellForGrid
//      cell.setupContents(withTitle: collection.name, andImage: collection.image ?? "")
//      return cell
//    }
  }
  
  
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    if isAddToMode {
      print("Clicked!--- Collection is selected.")
      let collection = collections[indexPath.row]
      print("Selected collection is -> \(collection.name)")
      // update model
      if let indices = indexPathsOfSelectedItems {
        for index in indices {
          let recipe = favoriteRecipes[index]
          if let collectionId = collection.firebaseId {
            // TODO: Check Hash
            print("Index(\(index)) - Recipe: \(recipe.title)/\(recipe.whichCollectionToBelong)")
            if !recipe.whichCollectionToBelong.contains(collectionId) {
              recipe.whichCollectionToBelong.append(collectionId)
              for id in recipe.whichCollectionToBelong {
                recipe.updateRecipeInCollection(collectionId: id)
              }
              print("This recipe doesn't belong to ID[\(collectionId)] \"\(collection.name)\"")
              recipe.updateWhichCollectionToBelong(userId: userID)
              print("Update the recipe @favorite ref and @recipeCollections.")
              collection.updateRecipeCollection(recipe: recipe)
            } else {
              print("This recipe already belong to ID[\(collectionId)] \"\(collection.name)\"")
            }
          }
        }
      }
      isAddToMode = false
      isEditing = false
      return
//      toggleCollectionView()
    }
    if typeSegmentControll.selectedSegmentIndex == ViewType.list.rawValue {
      if !isEditing {
        let recipe = favoriteRecipes[indexPath.row]
        selectedRecipeId = recipe.firebaseId
        self.performSegue(withIdentifier: "goToDetail", sender: self.collectionView)
      } else {
        self.toolBar.isHidden = false
      }
    } else {
      let collection = collections[indexPath.row]
      selectedCollectionId = collection.firebaseId
      self.performSegue(withIdentifier: "goToCollection", sender: self.collectionView)
    }
    
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "goToCollection" {
      let destVC = segue.destination as! CollectionVC
      destVC.collectionId = selectedCollectionId
    } else if segue.identifier == "goToDetail" {
      let destVC = segue.destination as! DetailVC
      destVC.recipeId = selectedRecipeId
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    if isEditing {
      if let indexPaths = collectionView.indexPathsForSelectedItems, indexPaths.count == 0 {
        self.toolBar.isHidden = true
      }
    }
  }
}
