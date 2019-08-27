

import UIKit
import HealthKit

class PastRunsListController: UITableViewController {
	
	private let batchSize = 40
	private var moreToBeLoaded = false
    
    private var runs: [CompletedRun] = []
    private let cellIdentifier = "RunTableCell"
    
	
	override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
		loadData()
    }
	
	// MARK: - Table View
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return moreToBeLoaded ? 2 : 1
	}
    
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0:
			if runs.count > 0 {
				return runs.count
			} else {
				return 0
			}
		case 1:
			return 1
		default:
			return 0
		}
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! RunTableCell
        let run = runs[indexPath.row]
		
		cell.nameLbl.text = run.type.localizable
        cell.dateLbl.text = run.name
        cell.distanceLbl.text = Appearance.format(distance: run.totalDistance)
		
        return cell
    }
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		tableView.deselectRow(at: indexPath, animated: true)
	}
	
	// MARK: - UI
	
	private func loadData() {

		
		let filter = HKQuery.predicateForObjects(from: HKSource.default())
		let limit: Int
		let predicate: NSPredicate
		
		if let last = runs.last {
			predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
				filter,
				NSPredicate(format: "%K <= %@", HKPredicateKeyPathStartDate, last.start as NSDate)
				])
			let sameDateCount = runs.count - (runs.firstIndex { $0.start == last.start } ?? runs.count)
			limit = sameDateCount + batchSize
		} else {
			predicate = filter
			limit = batchSize
		}
		
		let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
		let type = HKObjectType.workoutType()
		
		let workoutQuery = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [sortDescriptor]) { (_, r, err) in
			if let res = r as? [HKWorkout] {
				DispatchQueue.main.async {
					self.moreToBeLoaded = res.count >= limit
					let addLineCount: Int?
					do {
						var addAll = false
						// By searching the reversed collection we reduce comparison as both collections are sorted
						let revLoaded = self.runs.reversed()
						var count = 0
						let wasEmpty = self.runs.isEmpty
						for w in res {
							if addAll || !revLoaded.contains(where: { $0.raw == w }) {
								// Stop searching already loaded workouts when the first new workout is not present.
								addAll = true
								if let r = CompletedRun(raw: w) {
									self.runs.append(r)
									count += 1
								}
							}
						}
						
						addLineCount = wasEmpty ? nil : count
					}
					
					self.tableView.beginUpdates()
					if let added = addLineCount {
						let oldCount = self.tableView.numberOfRows(inSection: 0)
						self.tableView.insertRows(at: (oldCount ..< (oldCount + added)).map { IndexPath(row: $0, section: 0) }, with: .automatic)
					} else {
						self.tableView.reloadSections([0], with: .automatic)
					}
					
					if self.moreToBeLoaded && self.tableView.numberOfSections == 1 {
						self.tableView.insertSections([1], with: .automatic)
					} else if !self.moreToBeLoaded && self.tableView.numberOfSections > 1 {
						self.tableView.deleteSections([1], with: .automatic)
					}
					self.tableView.endUpdates()
				}
			}
		}
		
		HealthKitManager.healthStore.execute(workoutQuery)
	}
	
	// MARK: - Navigation
	
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let destinationController = segue.destination as? RunDetailController {
			guard let selectedCell = sender as? RunTableCell, let selectedIndex = tableView.indexPath(for: selectedCell) else {
				return
			}
			
            destinationController.run = runs[selectedIndex.row]
        }
    }
	
}
