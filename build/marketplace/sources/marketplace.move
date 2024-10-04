
/// Module: marketplace
module marketplace::marketplace {
use std::string::{String};
use sui::coin::{Coin,split, put,take};
use sui::balance::{Balance,zero};
use sui::sui::SUI;
use sui::event;
//define errors

const ETRUCKNOTAVAILABLE:u64=0;
const EINSUFFICIENTBALANCE:u64=1;
const EMUSTBERIGISTERED:u64=2;
const Error_Not_owner:u64=3;
const Error_Invalid_WithdrawalAmount:u64=4;


public struct User has key,store{
    id:UID,
    nameofuser:String,
    balance:Balance<SUI>,
    discountcouponpoints:u64
}
public struct Truck has store,drop{
    id:u64,
    owner:String,
    nameoftruck:String,
    registrationnumber:String,
    description:String,
    route:String,
    hirecost:u64,
    available:bool
    
   
}
    //struct for truck_transporter

    public struct Uber_Truck has key,store{
    id: UID,
    ownercap:ID,
    nameofcompany:String,
    officialemail:String,
    contactnumber:String,
    balance:Balance<SUI>,
    trucks:vector<Truck>,
    trucks_count:u64,
    registeredusers:vector<User>,
    bookedtrucks:vector<Truck>,
    refundrequest:vector<RefundRequest>

}

//truck owner capababilities
    public struct TruckOwner has key{
    id:UID,
    truckcompany_id:ID,
}

public struct RefundRequest has key,store{
    id:UID,
    reason:String,
    truckid:u64,
    userid:u64,
    recipient:address
}
//events
public struct Register_Uber_Truck_Company has copy,drop{
    name:String,
    company_id:ID
}

public struct TructBooked has copy,drop{
    name:String,
    by:String
}

public struct FundWithdrawal has copy,drop{
    recipient:address,
    amount:u64
}
public struct Refundrequest has copy,drop{
    success:String
}
public struct Refund has copy,drop{
    recipient:address,
    amount:u64
}
public  fun register_user(name:String,ctx:&mut TxContext):User{
    let userid=object::new(ctx);
    User{
        id:userid,
         nameofuser:name,
         balance:zero<SUI>(),
         discountcouponpoints:0
    }
}
public entry fun register_truck_company(
    name: String, 
    email: String, 
    contact: String, 
    ctx: &mut TxContext
) {
    // Check if the company name, email, or contact number are empty
    assert!(!string::is_empty(&name), 0); // Custom error for empty name
    assert!(!string::is_empty(&email), 1); // Custom error for empty email
    assert!(!string::is_empty(&contact), 2); // Custom error for empty contact number
    
    // Check if a company with the same name already exists
    // Assuming there’s a global map or resource to store all companies for uniqueness check
    let existing_company_opt = company_map::get_company_by_name(name); // Example: function to retrieve company by name
    assert!(existing_company_opt.is_none(), 3); // Error code for company already exists

    // Generate a new company ID
    let companyid = object::new(ctx);
    let company_id = object::uid_to_inner(&companyid);
    
    // Create a new Uber_Truck company instance
    let new_truck_company = Uber_Truck {
        id: companyid,
        ownercap: company_id,
        nameofcompany: name.clone(),
        officialemail: email,
        contactnumber: contact,
        balance: zero<SUI>(),
        trucks: vector::empty(),
        trucks_count: 0,
        registeredusers: vector::empty(),
        bookedtrucks: vector::empty(),
        refundrequest: vector::empty()
    };

    // Transfer ownership capability to the caller (sender)
    transfer::transfer(TruckOwner {
        id: object::new(ctx),
        truckcompany_id: company_id,
    }, tx_context::sender(ctx));

    // Emit an event indicating the successful registration of the truck company
    event::emit(Register_Uber_Truck_Company{
        name,
        company_id
    });

    // Share the newly created truck company object
    transfer::share_object(new_truck_company);

    // Optionally, store the new company in a global map/resource
    company_map::add_company(new_truck_company); // Example: storing the company in a global map for future lookups
}

//register truck
public entry fun register_truck(
    truckcompany: &mut Uber_Truck, 
    nameoftruck: String, 
    registrationnumber: String, 
    description: String, 
    cost: u64, 
    route: String, 
    ctx: &mut TxContext
) {
    // Check if the truck name or registration number are empty
    assert!(!string::is_empty(&nameoftruck), 0);  // Error code for empty truck name
    assert!(!string::is_empty(&registrationnumber), 1);  // Error code for empty registration number
    
    // Check if a truck with the same registration number already exists within the company
    let existing_truck = vector::find_if(truckcompany.trucks, 
        fun (truck: &Truck): bool { truck.registrationnumber == registrationnumber });
    assert!(existing_truck.is_none(), 2);  // Error code for truck already exists

    // Generate a new truck ID by incrementing the truck count
    let new_truck_id = truckcompany.trucks_count;
    
    // Create a new Truck instance
    let new_truck = Truck {
        id: new_truck_id,  // Assign the new ID
        owner: truckcompany.nameofcompany,
        nameoftruck,
        registrationnumber,
        description,
        hirecost: cost,
        route,
        available: true  // Truck is available when registered
    };

    // Add the new truck to the company's list of trucks
    vector::push_back(&mut truckcompany.trucks, new_truck);
    
    // Increment the truck count in the company
    truckcompany.trucks_count = truckcompany.trucks_count + 1;

    // Emit an event for truck registration
    event::emit(TruckRegistered{
        nameoftruck,
        registrationnumber
    });
}


  //hire for truck
   public entry fun hire_truck(
    truck_id: u64, 
    payment_coin: &mut Coin<SUI>, 
    userid: u64, 
    truckcompany: &mut Uber_Truck,  
    ctx: &mut TxContext
) {
    // Check if the truck_id is valid (i.e., within the range of registered trucks)
    assert!(truck_id < truckcompany.trucks_count, ETRUCKNOTAVAILABLE);  // Error if the truck doesn't exist

    // Fetch the truck based on the truck_id
    let truck = &mut truckcompany.trucks[truck_id];

    // Check if the truck is available
    assert!(truck.available, ETRUCKNOTAVAILABLE);  // Error if the truck is not available

    // Check if the user is registered
    assert!(userid < vector::length(&truckcompany.registeredusers), EMUSTBERIGISTERED);  // Error if user is not registered

    // Fetch the user from the registered users vector
    let user = &truckcompany.registeredusers[userid];

    // Check if the user has sufficient funds to hire the truck
    assert!(coin::value(payment_coin) >= truck.hirecost, EINSUFFICIENTBALANCE);  // Error if insufficient balance

    // Deduct the total hire cost from the user's payment
    let total_price = truck.hirecost;
    let paid_amount = coin::split(payment_coin, total_price, ctx);  

    // Add the deducted amount to the truck company's balance
    balance::put(&mut truckcompany.balance, paid_amount);

    // Update the truck availability status
    truck.available = false;

    // Create a new truck entry for the booked trucks
    let booked_truck = Truck {
        id: truck.id,
        owner: truck.owner.clone(),
        nameoftruck: truck.nameoftruck.clone(),
        registrationnumber: truck.registrationnumber.clone(),
        description: truck.description.clone(),
        hirecost: truck.hirecost,
        route: truck.route.clone(),
        available: truck.available
    };

    // Add the booked truck to the company's list of booked trucks
    vector::push_back(&mut truckcompany.bookedtrucks, booked_truck);

    // Emit an event indicating the truck has been booked
    event::emit(TructBooked{
        name: truck.nameoftruck.clone(),
        by: user.nameofuser.clone()
    });
}


//update truck status
   truckcompany.trucks[truck_id].available==false;
 let bookedTruck=Truck{
    id: truckcompany.trucks[truck_id].id,
        owner: truckcompany.trucks[truck_id].owner,
        nameoftruck:truckcompany.trucks[truck_id].nameoftruck,
        registrationnumber: truckcompany.trucks[truck_id].registrationnumber,
        description: truckcompany.trucks[truck_id].description,
        hirecost: truckcompany.trucks[truck_id].hirecost,
        route: truckcompany.trucks[truck_id].route,
        available: truckcompany.trucks[truck_id].available
 };
    truckcompany.bookedtrucks.push_back(bookedTruck);
    //generate event
    event::emit(TructBooked{
     name:truckcompany.trucks[truck_id].nameoftruck,
     by:truckcompany.registeredusers[userid].nameofuser
    });
}


  //owener withdraw all funds
 public fun withdraw_all_funds(
        cap: &TruckOwner,          // Admin Capability
        companytruck: &mut Uber_Truck,
        ctx: &mut TxContext,
        recipient:address     // Transaction context
    ) {
        assert!(object::id(companytruck)==cap.truckcompany_id, Error_Not_owner);

        let truck_balance=companytruck.balance.value();
        
        let remaining = take(&mut companytruck.balance, truck_balance, ctx);  // Withdraw amount
        transfer::public_transfer(remaining, recipient);  // Transfer withdrawn funds
       
        event::emit(FundWithdrawal {  // Emit FundWithdrawal event
            amount: truck_balance,
            recipient,
        });
    }

  //owener widthradw specific funds
 
   public fun withdraw_specific_funds(
        cap: &TruckOwner,          // Admin Capability
        companytruck: &mut Uber_Truck,
        ctx: &mut TxContext,
        amount:u64,
        recipient:address     // Transaction context
    ) {

        //verify amount
      assert!(amount > 0 && amount <= companytruck.balance.value(), Error_Invalid_WithdrawalAmount);
        assert!(object::id(companytruck)==cap.truckcompany_id, Error_Not_owner);

        let truck_balance=companytruck.balance.value();
        
        let remaining = take(&mut companytruck.balance, amount, ctx);  // Withdraw amount
        transfer::public_transfer(remaining, recipient);  // Transfer withdrawn funds
       
        event::emit(FundWithdrawal {  // Emit FundWithdrawal event
            amount: truck_balance,
            recipient,
        });
    }

  //apply for refund
public entry fun refund_request(recipient:address,truckcompany:&mut Uber_Truck, reason:String,truckid:u64,userid:u64,ctx:&mut TxContext){

//verify if user exists
 assert!(truckcompany.registeredusers.length()>=userid,EMUSTBERIGISTERED);

let new_refund_request=RefundRequest{
    id:object::new(ctx),
    reason,
    truckid,
    userid,
    recipient
};

truckcompany.refundrequest.push_back(new_refund_request);
 event::emit(Refundrequest{
    success:reason
 })
}
  //approve refund

   public fun owner_refund(
        cap: &TruckOwner,          
        companytruck: &mut Uber_Truck,
        ctx: &mut TxContext,
        amount:u64,
        
        userid:u64
    ) {

        
        assert!(object::id(companytruck)==cap.truckcompany_id, Error_Not_owner);

        let truck_balance=companytruck.balance.value();
        //verify if user has enough amount
        assert!(truck_balance>=amount ,EINSUFFICIENTBALANCE);

        let remaining = take(&mut companytruck.balance, amount, ctx);  // Withdraw amount
        transfer::public_transfer(remaining, companytruck.refundrequest[userid].recipient);  // Transfer withdrawn funds
       
        event::emit(Refund {  // Emit FundWithdrawal event
            amount,
            recipient:companytruck.refundrequest[userid].recipient,
        });
    }
}

