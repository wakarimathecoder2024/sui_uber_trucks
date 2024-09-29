
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
public entry fun register_truck_company(name:String,email:String,contact:String,ctx:&mut TxContext){

    let companyid=object::new(ctx);
    let company_id=object::uid_to_inner(&companyid);
    let new_truck_company= Uber_Truck {
        id:companyid,
        ownercap:company_id,
        nameofcompany:name,
        officialemail:email,
        contactnumber:contact,
        balance:zero<SUI>(),
        trucks:vector::empty(),
        trucks_count:0,
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
public entry fun register_truck(truckcompany:&mut Uber_Truck,nameoftruck:String,registrationnumber:String,description:String,cost:u64,route:String,_ctx:&mut TxContext){
//verify that company is already registered do it

    let trucks_count=0;
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

  //hire for truck
   public entry fun hire_truck(truck_id:u64, payment_coin: &mut Coin<SUI>,userid:u64,truckcompany:&mut Uber_Truck,  ctx: &mut TxContext){
//check if truck exists
assert!(truckcompany.trucks_count >truck_id,ETRUCKNOTAVAILABLE);
//check availability of truck
      assert!(truckcompany.trucks[truck_id].available==true,ETRUCKNOTAVAILABLE);
//check if user is registered

assert!(truckcompany.registeredusers.length()>=userid,EMUSTBERIGISTERED);
    //check user balance is enough to hire the truck
     assert!(payment_coin.value() >= truckcompany.trucks[truck_id].hirecost, EINSUFFICIENTBALANCE);
    let total_price=truckcompany.trucks[truck_id].hirecost;
 
    let paid = split(payment_coin, total_price, ctx);  

      put(&mut truckcompany.balance, paid); 

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

