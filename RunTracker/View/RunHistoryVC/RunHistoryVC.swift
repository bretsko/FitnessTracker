

import UIKit
import HealthKit

class RunHistoryVC: UITableViewController, HasHKManagerP {
    
    private let batchSize = 40
    private var moreToBeLoaded = false
    
    private var completedRuns: [CompletedRun] = []
    
    private let cellIdentifier = "RunTableCell"
    
    weak var hkManager: HKManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadData()
    }
    
    // MARK: - Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return moreToBeLoaded ? 2 : 1
    }
    
    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return completedRuns.count
        case 1:
            return 1
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! RunTableCell
        let run = completedRuns[indexPath.row]
        
        cell.nameLabel.text = run.type.rawValue
        cell.dateLabel.text = run.name
        cell.distanceLabel.text = Appearance.format(distance: run.totalDistance)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        //TODO: show the run
    }
    
    // MARK: - UI
    
    private func loadData() {
        
        let filter = HKQuery.predicateForObjects(from: HKSource.default())
        let limit: Int
        let predicate: NSPredicate
        
        if let last = completedRuns.last {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                filter,
                NSPredicate(format: "%K <= %@", HKPredicateKeyPathStartDate, last.start as NSDate)
            ])
            let sameDateCount = completedRuns.count - (completedRuns.firstIndex { $0.start == last.start } ?? completedRuns.count)
            limit = sameDateCount + batchSize
        } else {
            predicate = filter
            limit = batchSize
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let type = HKObjectType.workoutType()
        
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sortDescriptor]) { [weak self] (_, runs, err) in
            
            guard let runs = runs as? [HKWorkout],
                let strongSelf = self else {
                    return
            }
            
            DispatchQueue.main.async {
                
                strongSelf.moreToBeLoaded = runs.count >= limit
                let addLineCount: Int?
                
                var addAll = false
                // By searching the reversed collection we reduce comparison as both collections are sorted
                let revLoaded = strongSelf.completedRuns.reversed()
                var count = 0
                let wasEmpty = strongSelf.completedRuns.isEmpty
                
                runs.forEach { run in
                    
                    guard addAll || !revLoaded.contains(where: { $0.raw == run }) else {
                        return
                    }
                    // Stop searching already loaded workouts when the first new workout is not present.
                    addAll = true
                    if let completedRun = CompletedRun(raw: run) {
                        strongSelf.completedRuns.append(completedRun)
                        count += 1
                    }
                }
                
                addLineCount = wasEmpty ? nil : count
                
                strongSelf.tableView.beginUpdates()
                
                if let added = addLineCount {
                    let oldCount = strongSelf.tableView.numberOfRows(inSection: 0)
                    
                    let idxPaths = (oldCount ..< (oldCount + added)).map {
                        IndexPath(row: $0, section: 0)
                    }
                    
                    strongSelf.tableView.insertRows(at: idxPaths, with: .automatic)
                } else {
                    strongSelf.tableView.reloadSections([0], with: .automatic)
                }
                
                if strongSelf.moreToBeLoaded && strongSelf.tableView.numberOfSections == 1 {
                    strongSelf.tableView.insertSections([1], with: .automatic)
                } else if !strongSelf.moreToBeLoaded && strongSelf.tableView.numberOfSections > 1 {
                    strongSelf.tableView.deleteSections([1], with: .automatic)
                }
                strongSelf.tableView.endUpdates()
            }
        }
        
        healthStore?.execute(query)
    }
    
    // MARK: - Navigation
    
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//
////        if let navVC = segue.destination as? UINavigationController {
////            navVC.setNavigationBarHidden(false, animated: false)
////        }
//
//        guard let destVC = segue.destination as? CompletedRunVC else {
//            return
//        }
//        guard let selectedCell = sender as? RunTableCell,
//            let selectedIndex = tableView.indexPath(for: selectedCell) else {
//                return
//        }
//
//        destVC.run = completedRuns[selectedIndex.row]
//
//    }
}
