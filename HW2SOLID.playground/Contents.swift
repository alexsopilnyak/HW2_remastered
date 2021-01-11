import Foundation

#warning("ENUMS")
enum Role {
  case admin
  case regularUser
}

enum State {
  case logined
  case logouted
  case banned
}

enum SystemError: Error {
  case usernameIsBusy
  case userDataIncorrect
  case stateError
  case userBanned
  case userNotExist
  case permissionDenied
}


#warning("PROTOCOLS")
protocol User {
  var username: String {get set}
  var password: String {get set}
  var state: State {get set}
  var role: Role {get}
}

protocol DataStorageService {
  func add(user: User) throws
  func changeState(for username: String, state: State) throws
  func getUserFromStorage(username: String) -> User?
  func showAllRegularUsers()
}

protocol BettingStorageService {
  func appendBetFor(username: String, bet: Bet)
  func showBetsTo(username: String)
}

protocol AuthorizationService {
  func login(username: String, password: String, completion: (User) -> Void) throws
  func logout(username: String, completion: () -> Void)
  func registerNewUser(username: String, password: String, role: Role)
}

protocol BettingService {
  func take(bet: Bet, from username: String)
  func showBets(username: String)
}

#warning("USER AND ADMIN CLASSES")
class RegularUser: User {
  let role: Role
  
  var username: String
  var password: String
  var state: State = .logouted
  
  init(username: String, password: String, role: Role) {
    self.username = username
    self.password = password
    self.role = role
  }
  
  func place(bet: Bet, completion: (String, Bet) -> ()) {
    completion(username, bet)
  }
  
  func showMyBets(completion: (String) -> Void) {
    completion(username)
  }
}

class Admin: User {
  let role: Role
  
  var username: String
  var password: String
  var state: State = .logouted
  
  init(username: String, password: String, role: Role) {
    self.username = username
    self.password = password
    self.role = role
  }
  
  func showAllUsers(completion: () -> Void) {
    completion()
  }
  
  func ban(username: String, completion: (String, State) throws -> Void) {
    do {
      try completion(username, .banned)
      print("Admin banned \(username)")
    } catch {
      print("Unexpected error: \(error)")
    }
  }
}

#warning("BET STRUCT")
struct Bet {
  var description: String
}



#warning("DataStorage")
//MARK:- Data Storage

class DataStorage {
  private(set) var usersStorage: [String: User] = [:]
  private(set) var bets: [String: [Bet]] = [:]
  
  private func isUnique(username: String) -> Bool {
    !usersStorage.contains { $0.key == username}
  }
}


extension DataStorage: BettingStorageService {
  func appendBetFor(username: String, bet: Bet) {
    if bets[username] == nil {
      bets.updateValue([bet], forKey: username)
    }
    else {
      bets[username]?.append(bet)
    }
  }
  
  func showBetsTo(username: String) {
    if bets[username] == nil {
      print("Bets empty.")
    } else {
      print("\(username) bets: ")
      bets[username]?.forEach{ print($0.description) }
    }
  }
}


extension DataStorage: DataStorageService {
  func getUserFromStorage(username: String)  -> User? {
    guard let user = usersStorage[username] else { return nil }
    return user
  }
  
  func add(user: User) throws {
    if isUnique(username: user.username) {
      usersStorage[user.username] = user
    } else {
      throw SystemError.usernameIsBusy
    }
  }
  
  #warning("How change user.state if I will pass user not a username???")
  func changeState(for username: String, state: State ) throws  {
    guard var user = usersStorage[username] else { return }
    
    if user.role == .admin && state == .banned {
      throw SystemError.permissionDenied
    }
    
    if user.state != state {
      user.state = state
    } else {
      throw SystemError.stateError
    }
    
  }
  
  func showAllRegularUsers() {
    let regularUsers = usersStorage.filter{$1.role == .regularUser}
    print("All regular users:")
    regularUsers.forEach { print("Username: \($1.username), state: \($1.state)") }
  }
}


#warning("Authorization")
//MARK:- Authorization

class Authorization {
  private var dataStorage: DataStorageService
  
  init(dataStorage: DataStorageService) {
    self.dataStorage = dataStorage
  }
}

extension Authorization: AuthorizationService {
  func login(username: String, password: String, completion: (User) -> Void) throws  {
    guard let user = dataStorage.getUserFromStorage(username: username) else {
      throw SystemError.userNotExist
    }
    
    if user.state == .banned {
      throw SystemError.userBanned
    } else if user.username == username && user.password == password {
      do {
        try dataStorage.changeState(for: username, state: .logined)
        completion(user)
        print("User \(username) successful logined to system.")
      } catch SystemError.stateError {
        print("You have already logined to system.")
      }
      catch {
        print("Error: \(error)")
      }
    } else {
      throw SystemError.userDataIncorrect
    }
  }
  
  
  func logout(username: String, completion: () -> Void) {
    do {
      try dataStorage.changeState(for: username, state: .logouted)
      completion()
    } catch SystemError.stateError {
      print("You have already logouted from system.")
    } catch {
      print("Error: \(error)")
    }
  }
  
  func registerNewUser(username: String, password: String, role: Role) {
    var newUser: User
    
    switch role {
    case .admin:
      newUser = Admin(username: username, password: password, role: role)
    case .regularUser:
      newUser = RegularUser(username: username, password: password, role: role)
    }
    
    do {
      try dataStorage.add(user: newUser)
      print("New \(role) – \(username) – registered")
    } catch SystemError.usernameIsBusy {
      print("Username \(username) is busy! Try another username")
    } catch {
      print("Error: \(error)")
    }
  }
}


#warning("BettingSystem")
//MARK:- BettingSystem

class BettingSystem {
  private let dataStorage: BettingStorageService
  
  init(dataStorage: BettingStorageService) {
    self.dataStorage = dataStorage
  }
}

extension BettingSystem: BettingService {
  func take(bet: Bet, from username: String) {
    print("User \(username) place bet: \(bet.description)")
    dataStorage.appendBetFor(username: username, bet: bet)
  }
  
  func showBets(username: String) {
    dataStorage.showBetsTo(username: username)
  }
}


class System {
  let storageService: DataStorageService
  let bettingService: BettingService
  let authService: AuthorizationService
  
  var currentLoginedAdmin: Admin? {
    didSet {
      guard let oldValue = oldValue else {return }
      oldValue.state = .logouted
      print("Admin \(oldValue.username) logout from system")
    }
  }
  var currentLoginedUser: RegularUser? {
    didSet {
      guard let oldValue = oldValue else {return }
      if oldValue.state != .banned {
        oldValue.state = .logouted
      }
      print("User \(oldValue.username) logout from system")
    }
  }
  
  init(authService: AuthorizationService, storageService: DataStorageService, bettingService: BettingService) {
    self.authService = authService
    self.storageService = storageService
    self.bettingService = bettingService
  }
}

// MARK:- ========================= Initialization =========================

let dataStorage = DataStorage()
let auth = Authorization(dataStorage: dataStorage)
let betting = BettingSystem(dataStorage: dataStorage)
let system = System(authService: auth, storageService: dataStorage, bettingService: betting)

// MARK:- ========================= Process =========================
system.authService.registerNewUser(username: "Alex", password: "123", role: .regularUser)
system.authService.registerNewUser(username: "Vasya", password: "234", role: .regularUser)
system.authService.registerNewUser(username: "Admin", password: "234", role: .admin)
system.authService.registerNewUser(username: "Admin2", password: "234", role: .admin)


do {
  try system.authService.login(username: "Alex", password: "123") { (user) in
    system.currentLoginedUser = user as? RegularUser
  }
} catch {
  print(error.localizedDescription)
}

system.authService.logout(username: "Alex") {
  system.currentLoginedUser = nil
}

do {
  try system.authService.login(username: "Alex", password: "123") { (user) in
    system.currentLoginedUser = user as? RegularUser
  }
} catch {
  print(error.localizedDescription)
}

system.currentLoginedUser?.place(bet: Bet(description: "To me or to u"), completion: { (username, bet) in
  system.bettingService.take(bet: bet, from: username)
})

system.currentLoginedUser?.showMyBets(completion: { (username) in
  system.bettingService.showBets(username: username)
})

do {
  try system.authService.login(username: "Admin", password: "234") { (user) in
    system.currentLoginedAdmin = user as? Admin
  }
} catch {
  print(error.localizedDescription)
}

system.currentLoginedAdmin?.showAllUsers(completion: {
  system.storageService.showAllRegularUsers()
})

system.currentLoginedAdmin?.ban(username: "Alex", completion: { (username, state) in
  try system.storageService.changeState(for: username, state: state)
  system.currentLoginedUser = nil
})




