
/// Module: marketplace
module marketplace::marketplace {
use std::string::{String};
use sui::coin::{Coin,split, put,take};
use sui::balance::{Balance,zero};
use sui::sui::SUI;
use sui::event;
 use sui::object::uid_to_inner;
//define errors

const ETRUCKNOTAVAILABLE:u64=0;
const EINSUFFICIENTBALANCE:u64=1;
const EMUSTBERIGISTERED:u64=2;
const Error_Not_owner:u64=3;
const Error_Invalid_WithdrawalAmount:u64=4;
const ENOTBOOKED:u64=5;
const ENotOwner:u64=6;

public struct User has store{
    id:u64,
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
    nameofcompany:String,
    officialemail:String,
    contactnumber:String,
    balance:Balance<SUI>,
    trucks:vector<Truck>,
    trucks_count:u64,
    users_count:u64,
    registeredusers:vector<User>,
    bookedtrucks:vector<u64>,
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

public entry fun register_truck_company(name:String,email:String,contact:String,ctx:&mut TxContext){
//ensure its the only owner who can register truck
    let companyid=object::new(ctx);
    let company_id: ID=object::uid_to_inner(&companyid);
    let new_truck_company= Uber_Truck {
        id:companyid,
        nameofcompany:name,
        officialemail:email,
        contactnumber:contact,
        balance:zero<SUI>(),
        trucks:vector::empty(),
        trucks_count:0,
        users_count:0,
        registeredusers:vector::empty(),
         bookedtrucks:vector::empty(),
         refundrequest:vector::empty()
    };

     transfer::transfer(TruckOwner {
        id: object::new(ctx),
        truckcompany_id: company_id,
    }, tx_context::sender(ctx));

    event::emit(Register_Uber_Truck_Company{
        name,
        company_id
    });

     transfer::share_object(new_truck_company);
}
//register truck
public entry fun register_truck(truckcompany:&mut Uber_Truck,ownercap:&TruckOwner,nameoftruck:String,registrationnumber:String,description:String,cost:u64,route:String,_ctx:&mut TxContext){
//verify that company is already registered do it
  //let owner_id = sui::object::uid_to_inner(&truckcompany.id);
    assert!(&ownercap.truckcompany_id == object::uid_as_inner(&truckcompany.id),ENotOwner);

    let trucks_count=truckcompany.trucks_count;
    let new_truck=Truck {
        id:trucks_count,
        owner:truckcompany.nameofcompany,
        nameoftruck,
        registrationnumber,
        description,
        hirecost:cost,
        route,
        available:true
    };
    //add truck to company
 truckcompany.trucks.push_back(new_truck);
 truckcompany.trucks_count= truckcompany.trucks_count+1;

}
///register user

public entry fun user_sign_in(name:String,truckcompany:&mut Uber_Truck,_ctx:&mut TxContext){
    let mut index = 0;
    let user_count = vector::length(&truckcompany.registeredusers);
      let users_count=truckcompany.users_count;
   //check if user username is already taken
   while (index < user_count) {
        let user = &truckcompany.registeredusers[index];
        if (user.nameofuser == name) {
            // Abort or return early if the user is already registered
             abort 0
        };
        index = index + 1;
    };

    //register user
  let newuser= User{
         id:users_count,
         nameofuser:name,
         balance:zero<SUI>(),
         discountcouponpoints:0
    };
     truckcompany.users_count= truckcompany.users_count+1;
    truckcompany.registeredusers.push_back(newuser);
}

  //hire for truck
public entry fun hire_truck(truck_id:u64, payment_coin: &mut Coin<SUI>,userid:u64,truckcompany:&mut Uber_Truck,  ctx: &mut TxContext){
//check if truck exists
assert!(truckcompany.trucks.length() >=truck_id,ETRUCKNOTAVAILABLE);
//check availability of truck
      assert!(truckcompany.trucks[truck_id].available==true,ETRUCKNOTAVAILABLE);
//check if user is registered

assert!(truckcompany.registeredusers.length()>=userid,EMUSTBERIGISTERED);

    //check user balance is enough to hire the truck
     assert!(payment_coin.value() >= truckcompany.trucks[truck_id].hirecost, EINSUFFICIENTBALANCE);

    let total_price=truckcompany.trucks[truck_id].hirecost;
 
    let paid = payment_coin.split(total_price, ctx);  

    put(&mut truckcompany.balance, paid); 

//update truck status
   truckcompany.trucks[truck_id].available==false;
    truckcompany.bookedtrucks.push_back(truck_id);
    //generate event
    event::emit(TructBooked{
     name:truckcompany.trucks[truck_id].nameoftruck,
     by:truckcompany.registeredusers[userid].nameofuser
    });
}


  //owener withdraw all funds
 public entry fun withdraw_all_funds(
        cap: &TruckOwner,          // Admin Capability
        companytruck: &mut Uber_Truck,
        recipient:address,
        ctx: &mut TxContext,
    ) {
        //assert!(object::id(companytruck)==cap.truckcompany_id, Error_Not_owner);
        assert!(&cap.truckcompany_id == object::uid_as_inner(&companytruck.id),ENotOwner);
        let truck_balance=companytruck.balance.value();
        
        let remaining = take(&mut companytruck.balance, truck_balance, ctx);  // Withdraw amount
        transfer::public_transfer(remaining, recipient);  // Transfer withdrawn funds
       
        event::emit(FundWithdrawal {  // Emit FundWithdrawal event
            amount: truck_balance,
            recipient,
        });
    }

  //owener widthradw specific funds
 
   public entry fun withdraw_specific_funds(
        cap: &TruckOwner,          // Admin Capability
        companytruck: &mut Uber_Truck,
        amount:u64,
        recipient:address,
         ctx: &mut TxContext,
    ) {

        //verify amount
      assert!(amount > 0 && amount <= companytruck.balance.value(), Error_Invalid_WithdrawalAmount);
           assert!(&cap.truckcompany_id == object::uid_as_inner(&companytruck.id),ENotOwner);

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

//verify if the user has already booked truck

   let mut index = 0;
    let booked_count = vector::length(&truckcompany.bookedtrucks);
     let mut refundrequeststatement:bool=false;
   //check if user username is already taken
   while (index < booked_count) {
        let truck = &truckcompany.bookedtrucks[index];
        if (truck == truckid) {
            let new_refund_request=RefundRequest{
            id:object::new(ctx),
            reason,
            truckid,
            userid,
            recipient
        };

    truckcompany.refundrequest.push_back(new_refund_request);
    refundrequeststatement=true;
     event::emit(Refundrequest{
    success:reason
   })};
        index = index + 1;
    };

assert!(refundrequeststatement==true,ENOTBOOKED);

}
  //approve refund

   public entry fun owner_refund(
        cap: &TruckOwner,          
        companytruck: &mut Uber_Truck,
        amount:u64,
        userid:u64,
         ctx: &mut TxContext
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

