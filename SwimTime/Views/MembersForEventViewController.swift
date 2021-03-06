//
//  MembersForEventViewController.swift
//  SwimTime
//
//  Created by Mick Mossman on 5/9/18.
//  Copyright © 2018 Mick Mossman. All rights reserved.
//

import UIKit
import RealmSwift


protocol StoreFiltersDelegate {
    func updateDefaultFilters(team : SwimClub,ageGroup: PresetEventAgeGroups?)
}

class MembersForEventViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {

    let realm = try! Realm()
    var membersList : Results<Member>?
    var myfunc = appFunctions()
    var mydefs = appUserDefaults()
    var isRelay = false
    var pickerTeams : UIPickerView!
    var pickerAgeGroups : UIPickerView!
    
    var pickerTeamItems = [SwimClub]()
    var pickerAgeGroupItems = [PresetEventAgeGroups]()
    
    var lastAgeGroupFilter : PresetEventAgeGroups?//this has a dua purpose for preset events wiht preset age groups. This will be thw age group the ember is in for validation purposes
    var lastTeamFilter : SwimClub?
    
    var selectedEvent = Event()
    var selectedTeams : [SwimClub] = []
    
    
    var currentRelayNo = 1 //this is the relay number for this club.
    
    var usePreset : Bool = false
    
    
    var origtableframe  : CGRect = CGRect(x: 1.0, y: 1.0, width: 1.0, height: 1.0)
    var origFilterFrame : CGRect = CGRect(x: 1.0, y: 1.0, width: 1.0, height: 1.0)
    //var pickerViewFrame = CGRect(x: 1.0, y: 1.0 , width: 1.0, height: 1.0)
    
    let quickEntrySeg = "quickEntry"
  
    var origFilterViewHeight : CGFloat = 1.0
    
    var delegate : StoreFiltersDelegate?

    var backFromQuickEntry = false
    
    //one array for all members not in the event and their age at event time
    var memAges = [(memberid: 0, ageAtEvent: 0)]
    
    var filterShowing : Bool = false
    //one arrya for all existing event result members used to validate the numbers
    var memForEvent = [PresetEventMember]()
    
    
    @IBOutlet weak var lblTeam: UILabel!
    
    @IBOutlet weak var lblAgeGroup: UILabel!
    @IBOutlet weak var filterView: UIView!
    
    @IBOutlet weak var btnTeam: UIButton!
    
    @IBOutlet weak var btnAgeGroup: UIButton!
    
    
    @IBOutlet weak var myTableView: UITableView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let pse = selectedEvent.presetEvent {
            isRelay = pse.isRelay
            usePreset = true
        }
        
        
        navigationItem.setHidesBackButton(true, animated: false)
        //adjuts the height
        origtableframe = myTableView.frame
        
        origFilterViewHeight = filterView.frame.size.height
        
        
        origFilterFrame = CGRect(x: filterView.frame.origin.x, y: (view.frame.size.height - filterView.frame.size.height)/2, width: filterView.frame.size.width, height: filterView.frame.size.height)
        
        filterView.isHidden = true
        
        
        
        self.navigationController?.setToolbarHidden(false, animated: false)
        
        lblTeam.text = lastTeamFilter?.clubName
        
        loadPickerViews()
        
        hideShowFilter(self)
        
        startWindow()
       
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if backFromQuickEntry {
            if loadMembers() {
                
            }
            myTableView.reloadData()
            backFromQuickEntry = false
        }
    }
   
    
    
    //MARK: - IBActions
    
    
    @IBAction func filterClicked(_ sender: UIButton) {
        if checkRelayComplete() {
            if sender.tag == 0 {
                if pickerTeams.isHidden {
                    //if is relay mode then cant change clubs unless 0 or 4 are picked for the current club
                    if checkRelayComplete() {
                        
                        if let sName = lastTeamFilter?.clubName {
                            if let idx = pickerTeamItems.index(where: {$0.clubName == sName}) {
                                    pickerTeams.selectRow(idx, inComponent: 0, animated: true)
                                
                            }
                        }
                        pickerTeams.isHidden = false
                    }
                }else{
                    pickerTeams.isHidden = true
                }
                
                
            }else{
                if pickerAgeGroups.isHidden {
                    if let sName = lastAgeGroupFilter?.presetAgeGroupName {
                        if let idx = pickerAgeGroupItems.index(where: {$0.presetAgeGroupName == sName}) {
                            //print("name=\(sName) index=\(idx)")
                            pickerAgeGroups.selectRow(idx, inComponent: 0, animated: true)
                        }
                    }
                    pickerAgeGroups.isHidden = false
                }else{
                    pickerAgeGroups.isHidden = true
                }
                
            }
        }
    }
    
   
    
    @IBAction func hideShowFilter(_ sender: Any) {
        filterShowing = !filterShowing

        //hide the pickerview
        pickerTeams.isHidden = true
        pickerAgeGroups.isHidden = true
        
        let hidingFilterFrame = CGRect(x: 200.0, y: origFilterFrame.origin.y, width: origFilterFrame.size.width, height: origFilterFrame.size.height)
        UIView.animate(withDuration: 1, animations: {
            if self.filterShowing {
                self.filterView.frame = hidingFilterFrame
                self.filterView.frame = self.origFilterFrame
                self.view.bringSubviewToFront(self.filterView)
                self.filterView.isHidden = false
            
            }else{
                self.filterView.frame = self.origFilterFrame
                self.filterView.frame = hidingFilterFrame
                self.filterView.isHidden = true
            }
        })
   

    }
    
    @IBAction func quickEntry(_ sender: UIBarButtonItem) {
                backFromQuickEntry = true
                performSegue(withIdentifier: quickEntrySeg, sender: self)
    }
    
    
    func saveListDetails()-> Bool {
        var bok = false
        var useStagger = false
        
        if let psevent = selectedEvent.presetEvent {
            useStagger = psevent.useStaggerStart
        }
        
        
        
        if checkRelayComplete() {
            let memstosave = membersList?.filter("selectedForEvent=true")
            
            bok = true
            if memstosave?.count != 0 {
            
                    do {
                        try realm.write {
                            for mem in memstosave! {
                                
                                    mem.selectedForEvent = false
                                    let er = EventResult()
                                    er.eventResultId = mydefs.getNextEventResultId()
                                
                                    //change raceno to be thr id or webid if any
                                
                                
                                    er.ageAtEvent = myfunc.getAgeFromDate(fromDate: mem.dateOfBirth, toDate: selectedEvent.eventDate)//mem.age()
                                    
                                    er.expectedSeconds = myfunc.adjustOnekSecondsForDistance(distance: selectedEvent.eventDistance , timeinSeconds: mem.onekSeconds)
                                    
                                    if let clubforRace = mem.myClub.first {
                                        er.memberClubforRace = clubforRace
                                        //use racenos anyways jutsdont show them if flag not on
                                        er.raceNo = mem.webID == 0 ? mem.memberID : mem.webID
                                        //print(er.raceNo)
                                        
                                    }
                                        //this is the preset event for this members event
                                        let pse = self.memForEvent.filter({$0.memberid == mem.memberID}).first
                                        //print("\(pse.)
                                        if let psage = pse?.PresetAgeGroup {
                                            if psage.presetAgeGroupID != 0 {
                                                er.selectedAgeCategory = psage
                                                if useStagger {
                                                    er.staggerStartBy = psage.staggerSeconds
                                                    er.expectedSeconds += psage.staggerSeconds
                                                }
                                            }
                                        }
                                
                                
                                    if isRelay {
                                        er.relayNo = pse!.relayNo
                                        er.relayOrder = pse!.relayOrder
                                        er.expectedSeconds = er.expectedSeconds / 4
                                    }
                                    
                                    realm.add(er)
                                    mem.eventResults.append(er)
                                    selectedEvent.eventResults.append(er)
                                }
                            
                            
                        }
                    }catch{
                        showError(errmsg: "Cant save members")
                    }
                
            }
        }
        
        return bok
    }
    
    
    @IBAction func doneClicked(_ sender: UIBarButtonItem) {
        if saveListDetails() {
            if let agp = lastAgeGroupFilter {
                delegate?.updateDefaultFilters(team: lastTeamFilter!, ageGroup: agp)
            }else{
                delegate?.updateDefaultFilters(team: lastTeamFilter!, ageGroup: nil)
            }
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    // MARK: - my Data stuff
    
    func startWindow() {
        loadPresetEventMembers()
        
        if isRelay {
            currentRelayNo = getNextRelayNo(clubid: getClubID()) //last team filter is
        }
        setNavTitle()
        
        if loadMembers() {
            
        }
        myTableView.reloadData()
    }
    
    
    
    func checkRelayComplete() -> Bool {
        var ok = true
        if isRelay {
            let clubid = lastTeamFilter!.clubID
            let myarr = memForEvent.filter({$0.clubID == clubid && $0.relayNo == currentRelayNo})
            
            if myarr.count < 4 && myarr.count > 0 {
                ok = false
                showError(errmsg: "Current relay needs 4 members")
            }
        }
        
        return ok
    }
    func setNavTitle() {
        
        if isRelay {
            self.navigationItem.title = lastTeamFilter!.clubName + " Relay " + getRelayLetter()
        }else{
            self.navigationItem.title = selectedEvent.getRaceName()
        }
        
    
        
    }
    func loadPresetEventMembers() {
        
        //wil use this list to validate how many ppl as agegroups are allowed in each time
        //a member is selected
        memForEvent.removeAll()
        
        if usePreset {
            
                for er in selectedEvent.eventResults {
                    let mem = er.myMember.first!
                    if let agrp = er.selectedAgeCategory {
                        addMemberToPreset(mem: mem,agegrp: agrp,relayno: er.relayNo, relayorder: er.relayOrder)
                    }else{
                        addMemberToPreset(mem: mem,agegrp: nil,relayno: er.relayNo, relayorder: er.relayOrder)
                    }
                    
                }
            
            
        }
        
    }
    
    func addMemberToPreset(mem:Member,agegrp:PresetEventAgeGroups?,relayno:Int=0,relayorder:Int=0) {
        let pse = PresetEventMember()
        pse.memberid = mem.memberID
        pse.ageAtEvent = myfunc.getAgeFromDate(fromDate: mem.dateOfBirth, toDate: selectedEvent.eventDate)
        pse.gender = mem.gender
        pse.clubID = (mem.myClub.first?.clubID)!
        //print("\(pse.clubID)")
        pse.relayNo = relayno
        pse.relayOrder = relayorder
        if let ag =  agegrp  {
            //print("agegrpid=\(ag.presetAgeGroupID) name=\(ag.presetAgeGroupName)")
            pse.PresetAgeGroup = ag
            
        }

        memForEvent.append(pse)
    }
    
    
    func getNextRelayNo(clubid:Int) -> Int {
        //we need to go through the selected list and find either a relayno thats not used or a relayNo that is used but has less than 4 members
        var iNextRelayNo = 1
        
            for er in memForEvent {
                if er.clubID == clubid && er.relayNo == iNextRelayNo {
                    // see if there are 4 people
                    let myarr = memForEvent.filter({$0.clubID == clubid && $0.relayNo == iNextRelayNo})
                    if myarr.count == 4 {
                        iNextRelayNo += 1 //found 4 members so add 1
                    }else{
                        break
                    }
                    
                }
                
            }
        
        
        return iNextRelayNo
        
    }
    
    func getRelayLetter() -> String {
        var strLetter = ""
        switch currentRelayNo {
        case 1 :
            strLetter = "A"
            break
        case 2 :
            strLetter = "B"
            break
        case 3 :
            strLetter = "C"
            break
        case 4 :
            strLetter = "B"
            break
            
        default :
            break
            
        }
        return strLetter
    }
    func getCurrentRelayNo() -> Int {
        var nextRelayNo = 1
        var b1found = false
        var b2found = false
        var b3found = false
        var b4found = false
        if let st = lastTeamFilter {
            for index in 1...4 {
                let myarr = memForEvent.filter({$0.clubID == st.clubID && $0.relayNo == index})
                if myarr.count != 0 {
                    switch index {
                    case 1 :
                        b1found = true
                        break
                    case 2 :
                        b2found = true
                        break
                    case 3 :
                        b3found = true
                        break
                    case 4 :
                        b4found = true
                        break
                    default :
                        break
                    }
                }
            }
            
            
            
        }
        
        switch false {
        case b1found :
            nextRelayNo = 1
            break
        case b2found :
            nextRelayNo = 2
            break
        case b3found :
            nextRelayNo = 3
            break
        case b4found :
            nextRelayNo = 4
            break
        default :
            break
        }
        return nextRelayNo
    }
    func getRelayOrderForMember(thismemberid:Int) -> Int {
        
        if memForEvent.count != 0 {
            if let pse = memForEvent.filter({$0.memberid == thismemberid}).first {
                return pse.relayOrder
            }else{
                return 0
            }
            
        }else{
            return 0
        }
    }
    func getNextRelayOrder(clubid:Int) -> Int {
        
        //checkmemisvalid will check there is not 4 for currentRelayno
           var iNextRelayOrder = 1
        
            var b1found = false
            var b2found = false
            var b3found = false
            var b4found = false
        
        let myarr = memForEvent.filter({$0.clubID == clubid && $0.relayNo == currentRelayNo})
        
        if myarr.count != 0 {
            for er in myarr {
                if er.relayOrder == 1 {
                    b1found = true
                }
                if er.relayOrder == 2 {
                    b2found = true
                }
                if er.relayOrder == 3 {
                    b3found = true
                }
                if er.relayOrder == 4 {
                    b4found = true
                }
            }
            
        }
        
        switch false {
        case b1found :
            iNextRelayOrder = 1
            break
        case b2found :
            iNextRelayOrder = 2
            break
        case b3found :
            iNextRelayOrder = 3
            break
        case b4found :
            iNextRelayOrder = 4
            break
        default :
            break
        }
        
        return iNextRelayOrder
    }
    
    func checkMemIsvalid(mem:Member) -> Bool {
        var errMsg = ""
        if usePreset {
            if let pse = selectedEvent.presetEvent {
                if memForEvent.count != 0 {
                    if pse.maxPerEvent != 0 {
                        if pse.maxPerEvent == memForEvent.count {
                            errMsg = "Maximum number for the Race exceeded. Max entrants is \(pse.maxPerEvent)"
                        }
                    }
                    if pse.maxPerClub != 0 {
                        if let myclub = mem.myClub.first {
                            
                            let clubs  = memForEvent.filter({$0.clubID == myclub.clubID})
                            if clubs.count == pse.maxPerClub {
                                errMsg = "Maximum number exceeded. Max entrants for each club is \(pse.maxPerClub)"
                            }
                        }
                        
                    }
                    
                    if pse.maxPerGenderAndAgeGroup != 0 && pse.eventAgeGroups.count != 0 {
                        if let myclub = mem.myClub.first {
                            //print("\(mem.gender) agegrpid=\(lastAgeGroupFilter!.presetAgeGroupID) clubid=\(myclub.clubID)")
                            let matchingmems  = memForEvent.filter({$0.clubID == myclub.clubID && $0.gender == mem.gender && $0.PresetAgeGroup!.presetAgeGroupID == lastAgeGroupFilter!.presetAgeGroupID})
                                if matchingmems.count == pse.maxPerGenderAndAgeGroup {
                                    errMsg = "Maximum number per club, gender and age group exceeded. Max entrants for \(mem.gender) for \(lastAgeGroupFilter!.presetAgeGroupName) each club is \(pse.maxPerGenderAndAgeGroup)"
                                }
                            
                            
                           
                        }
                    }else{
                        if isRelay && errMsg.isEmpty {
                            //have checked member numbers and the like. cant add this guy form currentRelayNo if 4 already in
                            let marr = memForEvent.filter({$0.clubID == getClubID() && $0.relayNo == currentRelayNo})
                            if marr.count == pse.maxPerRelay {
                                errMsg = "Max for this relay and Team is \(pse.maxPerRelay)"
                            }
                        }
                    }
                
                }
            }
            
        }
        
        if !errMsg.isEmpty {
            showError(errmsg: errMsg)
        }else{
            
                if selectedEvent.presetEvent?.eventAgeGroups.count != 0 {
                    addMemberToPreset(mem: mem, agegrp: lastAgeGroupFilter)
                }else{
                    if isRelay {
                        addMemberToPreset(mem: mem, agegrp: nil,relayno: currentRelayNo,relayorder: getNextRelayOrder(clubid: getClubID()))
                    }else{
                       addMemberToPreset(mem: mem, agegrp: nil)
                    }
                    
                }
            
        }
        return errMsg.isEmpty
    }
    
    func getClubID() -> Int {
        if let thisclub = lastTeamFilter?.clubID {
            return thisclub
        }else{
            return 0
        }
    }
    func loadMembers() -> Bool{
        //Im trying to list Members that are NOT in this event
        
        
        var found : Bool = false
        
        //print(lastTeamFilter!.clubName)
        var membersNotInEvent : Results<Member> = realm.objects(Member.self).filter("ANY myClub.clubName = %@",lastTeamFilter!.clubName).sorted(byKeyPath: "memberName") //start wiht them all then filter if applicable
        
        //update the age list from the everyone list everyone
        
        memAges.removeAll()
        //print("count=\(membersNotInEvent.count)")
        for mem in membersNotInEvent {
            memAges.append((memberid: mem.memberID , ageAtEvent: myfunc.getAgeFromDate(fromDate: mem.dateOfBirth, toDate: selectedEvent.eventDate)))
        }
        
        //memForEvent is a list of the selctions and anyine already in the event so i can validate them
        //some preset event have rule for how many ppl per gender can be in it
        
        
        var memIdInEvent = [Int]()
        
         let resultsInEvent = selectedEvent.eventResults
        
        for rs in resultsInEvent {
            if let memberInEvent = rs.myMember.first {
                memIdInEvent.append(memberInEvent.memberID)
            }
            
        }
        //print("not in event count=\(membersNotInEvent.count)")
        if memIdInEvent.count != 0 {
            membersNotInEvent = membersNotInEvent.filter("NOT (memberID IN %@)",memIdInEvent)
        }
        //print("not in event count=\(membersNotInEvent.count)")
        var memidsForAge = [Int]()
        
        if let agp = lastAgeGroupFilter {
            
            
                    for ma in memAges {
                        if ma.ageAtEvent >= agp.minAge && agp.useOverMinForSelect {
                            memidsForAge.append(ma.memberid)
                        }else{
                            if ma.ageAtEvent <= agp.maxAge && !agp.useOverMinForSelect {
                                 memidsForAge.append(ma.memberid)
                            }
                        }
                    }
            
            //print("age is ok count=\(memidsForAge.count)")
            //we only want members that are in this age group. There may be none especialy for new clubs
            if memidsForAge.count != 0 {
                membersNotInEvent = membersNotInEvent.filter("memberID IN %@",memidsForAge)
            }else{
                //noone of correct age so clear the list
                //cant clear the Result using removeall so filter it out
                membersNotInEvent = membersNotInEvent.filter("memberID = %@",0)
            }
           //print("not in event count=\(membersNotInEvent.count)")
            
        }
        
       
        if (membersNotInEvent.count == 0) {
            let noDataLabel = UILabel(frame: CGRect(x: 0, y: 0, width: myTableView.bounds.size.width, height: myTableView.bounds.size.height))
            
            noDataLabel.text             = "No Members to List"
            noDataLabel.textColor        = UIColor.black
            noDataLabel.backgroundColor = UIColor.gray
            
            noDataLabel.textAlignment    = .center
            noDataLabel.font = UIFont(name:"Verdana",size:40)
            
            myTableView.backgroundView = noDataLabel;
            membersList = membersNotInEvent
            //myTableView.reloadData()
            //tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        }else{
            myTableView.backgroundView=nil
            
            //get all members not in event and create the age at event array to help the filter get people of the right ages
            //memAges.removeAll()
            
            membersList = membersNotInEvent
            found = true
        }
        return found
    }
    
    
    // MARK: - Table view data source
    
   func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return membersList?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return membersList?.count == 0 ? 0 : 1
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EventMemberCell", for: indexPath)
        
        configureCell(cell: cell, atIndexPath: indexPath)
        
        return cell
    }
    
    func configureCell(cell:UITableViewCell, atIndexPath indexPath:IndexPath) {
        
        
        let lh = membersList![indexPath.row + indexPath.section]
    
        cell.textLabel?.font = UIFont(name:"Helvetica", size:40.0)
        
        cell.textLabel?.text = lh.memberName
        
        cell.detailTextLabel?.font = UIFont(name:"Helvetica", size:20.0);
        
        cell.detailTextLabel?.textColor = UIColor.red
        
        
        var dtText = String(format:"(%@)   Age: %d",lh.gender,myfunc.getAgeFromDate(fromDate:lh.dateOfBirth, toDate: selectedEvent.eventDate))
        
        
        if let grp = lh.myClub.first {
            dtText = dtText + String(format:"   Team: %@",grp.clubName)
        }
        
        dtText = dtText + String(format:"   One K: %@",myfunc.convertSecondsToTime(timeinseconds: lh.onekSeconds))
        
        cell.detailTextLabel?.text = dtText
        cell.layer.cornerRadius = 8
        
        let imgFilePath = myfunc.getFullPhotoPath(memberid: lh.memberID)
        let imgMemberPhoto = UIImageView(image: UIImage(contentsOfFile: imgFilePath))
        
        
        cell.backgroundColor = UIColor(hexString: "89D8FC") //hard setting ths doesnt seem to work as well
        
        cell.accessoryView?.tintColor = UIColor.clear
        cell.accessoryView?.isHidden = false
        let imgframe = CGRect(x: 0.0, y: 8.0, width: 100.00, height: 90.00)
        
        if lh.selectedForEvent {
            var theimg = "ticknew"
            if isRelay {
                let thismemrelayorder = getRelayOrderForMember(thismemberid: lh.memberID)
                switch thismemrelayorder {
                case 1 :
                    theimg = "one"
                    break
                case 2 :
                    theimg = "two"
                    break
                case 3 :
                    theimg = "three"
                    break
                case 4 :
                    theimg = "four"
                    break
                default :
                    break
                }
            }
            let imageView = UIImageView(image: UIImage(named: theimg))
            //cell.accessoryView?.frame = imgframe
            imageView.frame = imgframe
            imageView.layer.masksToBounds = true
            //imageView.sizeToFit()
            cell.accessoryView = imageView
            
        }else {
            if imgMemberPhoto.image != nil {
                
               
                imgMemberPhoto.frame = imgframe
                imgMemberPhoto.layer.masksToBounds = true
                imgMemberPhoto.layer.cornerRadius = 20.0
                cell.accessoryView = imgMemberPhoto
                
                
            }else{
                cell.accessoryView?.isHidden = true
            }
            
        }
        
        
        
        
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 3.0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = UIColor.clear
        return headerView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let mem = membersList![indexPath.row + indexPath.section]
        
        var bok = false
        
        if mem.selectedForEvent  {
            //remove if was selected
            bok = true
            if let mxm = memForEvent.index(where: {$0.memberid == mem.memberID}) {
                memForEvent.remove(at: mxm)
            }
            
            
        }else{
            if checkMemIsvalid(mem: mem) {
                bok = true
            }
        }
        
        if bok {
            do {
                try realm.write {
                    mem.selectedForEvent = !mem.selectedForEvent
                    
                    
                }
            }catch{
                showError(errmsg: "Couldnt update item")
            }
            tableView.reloadData()
        }
        
        
    }
    
  
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == quickEntrySeg {
            let vc = segue.destination as! MembersViewController
            if let thisclub = lastTeamFilter {
                vc.selectedClub = thisclub
            }
        }
    }
    
    //MARK: - Errors
    func showError(errmsg:String) {
        let alert = UIAlertController(title: "Error", message: errmsg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))

        present(alert, animated: true, completion: nil)
        
    }
    
}
extension MembersForEventViewController : UIPickerViewDelegate,UIPickerViewDataSource {
    func loadPickerViews() {
        pickerTeams = myfunc.makePickerView()
        pickerAgeGroups = myfunc.makePickerView()
        pickerTeams.delegate = self
        pickerTeams.dataSource = self
        
        pickerAgeGroups.delegate = self
        pickerAgeGroups.dataSource = self
        
        
        //configurePickerView(pckview: pickerTeams)
        pickerTeams.tag = 1
        pickerAgeGroups.tag = 2
        
        let defpickerViewFrame = myfunc.getPickerViewFrame()
        
        let pickerViewFrame = CGRect(x: defpickerViewFrame.origin.x , y: (view.frame.size.height/2) + origFilterFrame.size.height, width: defpickerViewFrame.size.width, height: defpickerViewFrame.size.height)
        
        
        pickerTeams.frame = pickerViewFrame
        pickerAgeGroups.frame = pickerViewFrame
        
        
        
        view.addSubview(pickerTeams)
        view.addSubview(pickerAgeGroups)
        
        loadPickerViewTeams()
        loadPickerViewAgeGroups()
        
        pickerTeams.isHidden = true
        pickerAgeGroups.isHidden = true
    }
    
    private func loadPickerViewTeams() {
        pickerTeamItems = selectedTeams
        if pickerTeamItems.count == 1 {
            btnTeam.isHidden = true
        }
    }
    
    func loadPickerViewAgeGroups() {
        if usePreset  {
            if selectedEvent.presetEvent?.eventAgeGroups.count != 0 {
                pickerAgeGroupItems = Array(selectedEvent.presetEvent!.eventAgeGroups)
                //set lastAgegroup filter
                var selagegrp = PresetEventAgeGroups()
                if let _ = lastAgeGroupFilter {
                    selagegrp = lastAgeGroupFilter!
                }else{
                    for ag in selectedEvent.presetEvent!.eventAgeGroups {
                        selagegrp = ag
                        if ag.useOverMinForSelect {
                            break
                        }
                    }
                }
                lastAgeGroupFilter = selagegrp
                lblAgeGroup.text = selagegrp.presetAgeGroupName
            }else{
                loadAllAgeGroups()
            }
            
        }else{
            loadAllAgeGroups()
        }
    }
    func loadAllAgeGroups() {
        pickerAgeGroupItems = Array(realm.objects(PresetEventAgeGroups.self).sorted(byKeyPath: "presetAgeGroupID")).filter({$0.presetAgeGroupID != 0})
        
        //for some reasin Im getting extra age groups create with a 0 id and no name. Have changed the property selectedAgeGroup in EventResult from a list to an optional PresetEventAgeGroup
        
//        print("count=\(pickerAgeGroupItems.count)")
//
//        for ps in pickerAgeGroupItems {
//
//            print(String(format:"id=%d   %@",ps.presetAgeGroupID , ps.presetAgeGroupName))
//
//        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if pickerView.tag == 1 {
            return pickerTeamItems.count
        }else{
            //print("count=\(pickerAgeGroupItems.count)")
            return pickerAgeGroupItems.count
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        if pickerView.tag == 1 {
            
            return pickerTeamItems[row].clubName
        }else{
            //print(pickerAgeGroupItems[row].presetAgeGroupName)
            return pickerAgeGroupItems[row].presetAgeGroupName
            
        }
        
        
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
       
        if saveListDetails() {
        
            if pickerView.tag == 1 {
                lastTeamFilter = pickerTeamItems[row]
                lblTeam.text = lastTeamFilter?.clubName
                if isRelay {
                    currentRelayNo = getNextRelayNo(clubid: lastTeamFilter!.clubID)
                    setNavTitle()
                }
            }else{
                
                lastAgeGroupFilter = pickerAgeGroupItems[row]
                lblAgeGroup.text = lastAgeGroupFilter?.presetAgeGroupName
            }
            
            startWindow()
            
            pickerView.isHidden = true
        }
        
    }

    

}
