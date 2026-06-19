---------------- MODULE HCSP_Sovereign_Master_Specification ----------------
EXTENDS Reals, Sequences, Integers, FiniteSets

(* * HCSP SOVEREIGN SYSTEM - MASTER SPECIFICATION 2.1
 * Includes Emergency Protocol & Time-linked Precision
 * -----------------------------------------------------------
 *)

CONSTANTS 
    XI, GAMMA, ETA, MaxQueueSize, SelfHealTimer, TimeStep

VARIABLES 
    psi, time_ticks, s_val, r_val, n_val, psi_zero_timer, 
    request_queue, current_response, response_time

(* Security Constraints & Logical Bounds *)
ASSUME XI > 1 /\ GAMMA > 0 /\ ETA > 0 /\ MaxQueueSize > 0 
ASSUME SelfHealTimer > 0 /\ SelfHealTimer < 10
ASSUME TimeStep > 0

(* 1. MATHEMATICAL FORMULATION *)
Derivative == (ETA * ((s_val * r_val) / (1 + XI * n_val))) - (GAMMA * psi)

Deterministic_Condition == 
    ((s_val * r_val) / (1 + XI * n_val)) > (GAMMA / ETA)

(* 2. EMERGENCY & HEALING STATES *)
Emergency == psi < 0.1 /\ n_val > 0.8

Emergency_Action ==
    /\ Emergency
    /\ s_val' = 1.0 /\ r_val' = 1.0 /\ n_val' = 0.1
    /\ psi' = 0.5 (* Immediate forced boost *)
    /\ current_response' = "EMERGENCY_STABILIZATION"
    /\ response_time' = TimeStep
    /\ psi_zero_timer' = 0
    /\ UNCHANGED <<request_queue, time_ticks>>

(* 3. SYSTEM STATE INITIALIZATION *)
Init == 
    /\ psi = 0.0 /\ time_ticks = 0
    /\ s_val = 1.0 /\ r_val = 1.0 /\ n_val = 0.5
    /\ psi_zero_timer = 0
    /\ request_queue = << >> /\ current_response = "NONE" /\ response_time = 0.0

(* 4. USDL INTERFACE LOGIC *)
Process_Request(req) ==
    IF ((s_val * r_val) / (1 + XI * req.noise_level)) > (GAMMA / ETA) THEN
        /\ psi' = 1.0 /\ psi_zero_timer' = 0
        /\ current_response' = "DETERMINISTIC_SUCCESS" /\ response_time' = TimeStep
        /\ UNCHANGED <<s_val, r_val, n_val>>
    ELSE
        /\ psi' = psi + (Derivative * TimeStep)
        /\ psi_zero_timer' = IF psi = 0 THEN psi_zero_timer + 1 ELSE psi_zero_timer
        /\ current_response' = "REJECTED_UNCERTAINTY" /\ response_time' = TimeStep
        /\ UNCHANGED <<s_val, r_val, n_val>>

Adjust_Constants(req) ==
    /\ s_val' = req.new_S /\ r_val' = req.new_R /\ n_val' = req.new_N
    /\ current_response' = "CONSTANTS_ADJUSTED" /\ response_time' = TimeStep
    /\ psi_zero_timer' = psi_zero_timer /\ UNCHANGED <<psi>>

Self_Heal ==
    /\ ~Emergency
    /\ psi = 0.0 /\ psi_zero_timer >= SelfHealTimer
    /\ s_val' = 1.0 /\ r_val' = 1.0 /\ n_val' = 0.1
    /\ current_response' = "SELF_HEALING_ACTIVATED"
    /\ psi_zero_timer' = 0 /\ psi' = psi /\ response_time' = TimeStep
    /\ UNCHANGED <<request_queue, time_ticks>>

(* 5. MASTER TRANSITION LOGIC *)
Next ==
    \/ Emergency_Action
    \/ /\ ~Emergency
       /\ request_queue /= << >>
       /\ LET req == Head(request_queue) IN
          /\ IF req.type = "PROCESS" THEN Process_Request(req)
             ELSE Adjust_Constants(req)
          /\ request_queue' = Tail(request_queue)
       /\ time_ticks' = time_ticks + 1
    \/ /\ ~Emergency
       /\ Self_Heal
    \/ /\ ~Emergency
       /\ request_queue = << >>
       /\ psi' = psi + (Derivative * TimeStep)
       /\ UNCHANGED <<s_val, r_val, n_val, request_queue, current_response, response_time, psi_zero_timer, time_ticks>>

Spec == Init /\ [][Next]_<<psi, time_ticks, s_val, r_val, n_val, psi_zero_timer, request_queue, current_response, response_time>>

=============================================================================
