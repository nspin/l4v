(*
 * Copyright 2023, Proofcraft Pty Ltd
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

(*
   The refinement relation between abstract and concrete states
*)

theory StateRelation
imports InvariantUpdates_H
begin

context begin interpretation Arch .

definition cte_map :: "cslot_ptr \<Rightarrow> machine_word" where
  "cte_map \<equiv> \<lambda>(oref, cref). oref + (of_bl cref << cte_level_bits)"

lemmas cte_map_def' = cte_map_def[simplified cte_level_bits_def shiftl_t2n mult_ac, simplified]

definition lookup_failure_map :: "ExceptionTypes_A.lookup_failure \<Rightarrow> Fault_H.lookup_failure" where
  "lookup_failure_map \<equiv> \<lambda>lf. case lf of
     ExceptionTypes_A.InvalidRoot         \<Rightarrow> Fault_H.InvalidRoot
   | ExceptionTypes_A.MissingCapability n \<Rightarrow> Fault_H.MissingCapability n
   | ExceptionTypes_A.DepthMismatch n m   \<Rightarrow> Fault_H.DepthMismatch n m
   | ExceptionTypes_A.GuardMismatch n g   \<Rightarrow> Fault_H.GuardMismatch n (of_bl g) (length g)"

primrec arch_fault_map :: "Machine_A.AARCH64_A.arch_fault \<Rightarrow> arch_fault" where
  "arch_fault_map (Machine_A.AARCH64_A.VMFault ptr msg) = VMFault ptr msg"
| "arch_fault_map (Machine_A.AARCH64_A.VGICMaintenance datalist) = VGICMaintenance datalist "
| "arch_fault_map (Machine_A.AARCH64_A.VPPIEvent irq) = VPPIEvent irq"
| "arch_fault_map (Machine_A.AARCH64_A.VCPUFault data) = VCPUFault data"

primrec fault_map :: "ExceptionTypes_A.fault \<Rightarrow> Fault_H.fault" where
  "fault_map (ExceptionTypes_A.CapFault ref bool failure) =
     Fault_H.CapFault ref bool (lookup_failure_map failure)"
| "fault_map (ExceptionTypes_A.ArchFault arch_fault) =
     Fault_H.ArchFault (arch_fault_map arch_fault)"
| "fault_map (ExceptionTypes_A.UnknownSyscallException n) =
     Fault_H.UnknownSyscallException n"
| "fault_map (ExceptionTypes_A.UserException x y) =
     Fault_H.UserException x y"

type_synonym obj_relation_cut = "Structures_A.kernel_object \<Rightarrow> Structures_H.kernel_object \<Rightarrow> bool"
type_synonym obj_relation_cuts = "(machine_word \<times> obj_relation_cut) set"

definition vmrights_map :: "rights set \<Rightarrow> vmrights" where
  "vmrights_map S \<equiv> if AllowRead \<in> S
                     then (if AllowWrite \<in> S then VMReadWrite else VMReadOnly)
                     else VMKernelOnly"

definition zbits_map :: "nat option \<Rightarrow> zombie_type" where
  "zbits_map N \<equiv> case N of Some n \<Rightarrow> ZombieCNode n | None \<Rightarrow> ZombieTCB"

definition mdata_map ::
  "(Machine_A.AARCH64_A.asid \<times> vspace_ref) option \<Rightarrow> (asid \<times> vspace_ref) option" where
  "mdata_map = map_option (\<lambda>(asid, ref). (ucast asid, ref))"

primrec acap_relation :: "arch_cap \<Rightarrow> arch_capability \<Rightarrow> bool" where
  "acap_relation (arch_cap.ASIDPoolCap p asid) c =
     (c = ASIDPoolCap p (ucast asid))"
| "acap_relation (arch_cap.ASIDControlCap) c =
     (c = ASIDControlCap)"
| "acap_relation (arch_cap.FrameCap p rghts sz dev data) c =
     (c = FrameCap p (vmrights_map rghts) sz dev (mdata_map data))"
| "acap_relation (arch_cap.PageTableCap p pt_t data) c =
     (c = PageTableCap p pt_t (mdata_map data))"
| "acap_relation (arch_cap.VCPUCap vcpu) c  = (c =
        arch_capability.VCPUCap vcpu)"

primrec cap_relation :: "cap \<Rightarrow> capability \<Rightarrow> bool" where
  "cap_relation Structures_A.NullCap c =
     (c = Structures_H.NullCap)"
| "cap_relation Structures_A.DomainCap c =
     (c = Structures_H.DomainCap)"
| "cap_relation (Structures_A.UntypedCap dev ref n f) c =
     (c = Structures_H.UntypedCap dev ref n f)"
| "cap_relation (Structures_A.EndpointCap ref b r) c =
     (c = Structures_H.EndpointCap ref b (AllowSend \<in> r) (AllowRecv \<in> r) (AllowGrant \<in> r)
                                         (AllowGrantReply \<in> r))"
| "cap_relation (Structures_A.NotificationCap ref b r) c =
     (c = Structures_H.NotificationCap ref b (AllowSend \<in> r) (AllowRecv \<in> r))"
| "cap_relation (Structures_A.CNodeCap ref n L) c =
     (c = Structures_H.CNodeCap ref n (of_bl L) (length L))"
| "cap_relation (Structures_A.ThreadCap ref) c =
     (c = Structures_H.ThreadCap ref)"
| "cap_relation (Structures_A.ReplyCap ref master r) c =
     (c = Structures_H.ReplyCap ref master (AllowGrant \<in> r))"
| "cap_relation (Structures_A.IRQControlCap) c =
     (c = Structures_H.IRQControlCap)"
| "cap_relation (Structures_A.IRQHandlerCap irq) c =
     (c = Structures_H.IRQHandlerCap irq)"
| "cap_relation (Structures_A.ArchObjectCap a) c =
     (\<exists>a'. acap_relation a a' \<and> c = Structures_H.ArchObjectCap a')"
| "cap_relation (Structures_A.Zombie p b n) c =
     (c = Structures_H.Zombie p (zbits_map b) n)"


definition cte_relation :: "cap_ref \<Rightarrow> obj_relation_cut" where
  "cte_relation y \<equiv> \<lambda>ko ko'. \<exists>sz cs cte cap. ko = CNode sz cs \<and> ko' = KOCTE cte
                                              \<and> cs y = Some cap \<and> cap_relation cap (cteCap cte)"

definition abs_asid_entry :: "asidpool_entry \<Rightarrow> asid_pool_entry" where
  "abs_asid_entry ap = AARCH64_A.ASIDPoolVSpace (apVMID ap) (apVSpace ap)"

definition asid_pool_relation :: "asid_pool \<Rightarrow> asidpool \<Rightarrow> bool" where
  "asid_pool_relation \<equiv> \<lambda>p p'. p = map_option abs_asid_entry \<circ> inv ASIDPool p' \<circ> ucast"

lemma inj_ASIDPool[simp]:
  "inj ASIDPool"
  by (auto intro: injI)

lemma asid_pool_relation_def':
  "asid_pool_relation ap (ASIDPool ap') =
    (\<forall>asid_low. ap asid_low = map_option abs_asid_entry (ap' (ucast asid_low)))"
  by (auto simp add: asid_pool_relation_def)

definition vgic_map :: "gic_vcpu_interface \<Rightarrow> gicvcpuinterface" where
  "vgic_map \<equiv> \<lambda>v. VGICInterface (vgic_hcr v) (vgic_vmcr v) (vgic_apr v) (vgic_lr v)"

definition vcpu_relation :: "AARCH64_A.vcpu \<Rightarrow> vcpu \<Rightarrow> bool" where
  "vcpu_relation \<equiv> \<lambda>v v'. vcpu_tcb v = vcpuTCBPtr v' \<and>
                           vgic_map (vcpu_vgic v) = vcpuVGIC v' \<and>
                           vcpu_regs v = vcpuRegs v' \<and>
                           vcpu_vppi_masked v = vcpuVPPIMasked v' \<and>
                           vcpu_vtimer v = vcpuVTimer v'"

definition ntfn_relation :: "Structures_A.notification \<Rightarrow> Structures_H.notification \<Rightarrow> bool" where
  "ntfn_relation \<equiv> \<lambda>ntfn ntfn'.
     (case ntfn_obj ntfn of
        Structures_A.IdleNtfn      \<Rightarrow> ntfnObj ntfn' = Structures_H.IdleNtfn
      | Structures_A.WaitingNtfn q \<Rightarrow> ntfnObj ntfn' = Structures_H.WaitingNtfn q
      | Structures_A.ActiveNtfn b  \<Rightarrow> ntfnObj ntfn' = Structures_H.ActiveNtfn b)
     \<and> ntfn_bound_tcb ntfn = ntfnBoundTCB ntfn'"

definition ep_relation :: "Structures_A.endpoint \<Rightarrow> Structures_H.endpoint \<Rightarrow> bool" where
 "ep_relation \<equiv> \<lambda>ep ep'. case ep of
    Structures_A.IdleEP   \<Rightarrow> ep' = Structures_H.IdleEP
  | Structures_A.RecvEP q \<Rightarrow> ep' = Structures_H.RecvEP q
  | Structures_A.SendEP q \<Rightarrow> ep' = Structures_H.SendEP q"

definition fault_rel_optionation :: "ExceptionTypes_A.fault option \<Rightarrow> Fault_H.fault option \<Rightarrow> bool"
  where
  "fault_rel_optionation \<equiv> \<lambda>f f'. f' = map_option fault_map f"

primrec thread_state_relation :: "Structures_A.thread_state \<Rightarrow> Structures_H.thread_state \<Rightarrow> bool"
  where
  "thread_state_relation (Structures_A.Running) ts'
     = (ts' = Structures_H.Running)"
| "thread_state_relation (Structures_A.Restart) ts'
     = (ts' = Structures_H.Restart)"
| "thread_state_relation (Structures_A.Inactive) ts'
     = (ts' = Structures_H.Inactive)"
| "thread_state_relation (Structures_A.IdleThreadState) ts'
     = (ts' = Structures_H.IdleThreadState)"
| "thread_state_relation (Structures_A.BlockedOnReply) ts'
     = (ts' = Structures_H.BlockedOnReply)"
| "thread_state_relation (Structures_A.BlockedOnReceive oref sp) ts'
     = (ts' = Structures_H.BlockedOnReceive oref (receiver_can_grant sp))"
| "thread_state_relation (Structures_A.BlockedOnSend oref sp) ts'
     = (ts' = Structures_H.BlockedOnSend oref (sender_badge sp)
                         (sender_can_grant sp) (sender_can_grant_reply sp) (sender_is_call sp))"
| "thread_state_relation (Structures_A.BlockedOnNotification oref) ts'
     = (ts' = Structures_H.BlockedOnNotification oref)"

definition arch_tcb_relation :: "Structures_A.arch_tcb \<Rightarrow> Structures_H.arch_tcb \<Rightarrow> bool" where
  "arch_tcb_relation \<equiv>
     \<lambda>atcb atcb'. tcb_context atcb = atcbContext atcb' \<and> tcb_vcpu atcb = atcbVCPUPtr atcb'"

definition tcb_relation :: "Structures_A.tcb \<Rightarrow> Structures_H.tcb \<Rightarrow> bool" where
  "tcb_relation \<equiv> \<lambda>tcb tcb'.
     tcb_fault_handler tcb = to_bl (tcbFaultHandler tcb')
   \<and> tcb_ipc_buffer tcb = tcbIPCBuffer tcb'
   \<and> arch_tcb_relation (tcb_arch tcb) (tcbArch tcb')
   \<and> thread_state_relation (tcb_state tcb) (tcbState tcb')
   \<and> fault_rel_optionation (tcb_fault tcb) (tcbFault tcb')
   \<and> cap_relation (tcb_ctable tcb) (cteCap (tcbCTable tcb'))
   \<and> cap_relation (tcb_vtable tcb) (cteCap (tcbVTable tcb'))
   \<and> cap_relation (tcb_reply tcb) (cteCap (tcbReply tcb'))
   \<and> cap_relation (tcb_caller tcb) (cteCap (tcbCaller tcb'))
   \<and> cap_relation (tcb_ipcframe tcb) (cteCap (tcbIPCBufferFrame tcb'))
   \<and> tcb_bound_notification tcb = tcbBoundNotification tcb'
   \<and> tcb_mcpriority tcb = tcbMCP tcb'"

definition
  other_obj_relation :: "Structures_A.kernel_object \<Rightarrow> Structures_H.kernel_object \<Rightarrow> bool"
where
  "other_obj_relation obj obj' \<equiv>
   (case (obj, obj') of
      (TCB tcb, KOTCB tcb') \<Rightarrow> tcb_relation tcb tcb'
    | (Endpoint ep, KOEndpoint ep') \<Rightarrow> ep_relation ep ep'
    | (Notification ntfn, KONotification ntfn') \<Rightarrow> ntfn_relation ntfn ntfn'
    | (ArchObj (AARCH64_A.ASIDPool ap), KOArch (KOASIDPool ap')) \<Rightarrow> asid_pool_relation ap ap'
    | (ArchObj (AARCH64_A.VCPU vcpu), KOArch (KOVCPU vcpu')) \<Rightarrow> vcpu_relation vcpu vcpu'
    | _ \<Rightarrow> False)"


primrec pte_relation' :: "AARCH64_A.pte \<Rightarrow> AARCH64_H.pte \<Rightarrow> bool" where
  "pte_relation' AARCH64_A.InvalidPTE x =
     (x = AARCH64_H.InvalidPTE)"
(* FIXME AARCH64: change Haskell to ppn-style, but use a 36 bit word like in C: *)
| "pte_relation' (AARCH64_A.PageTablePTE ppn) x =
     (x = AARCH64_H.PageTablePTE (ucast ppn))"
| "pte_relation' (AARCH64_A.PagePTE page_addr is_small attrs rights) x =
     (x = AARCH64_H.PagePTE page_addr is_small (Global \<in> attrs) (Execute \<notin> attrs) (Device \<in> attrs)
                            (vmrights_map rights))"

definition pte_relation :: "machine_word \<Rightarrow> Structures_A.kernel_object \<Rightarrow> kernel_object \<Rightarrow> bool" where
 "pte_relation y \<equiv> \<lambda>ko ko'. \<exists>pt pte. ko = ArchObj (PageTable pt) \<and> ko' = KOArch (KOPTE pte)
                                      \<and> pte_relation' (pt_apply pt y) pte"

primrec aobj_relation_cuts :: "AARCH64_A.arch_kernel_obj \<Rightarrow> machine_word \<Rightarrow> obj_relation_cuts" where
  "aobj_relation_cuts (DataPage dev sz) x =
     { (x + (n << pageBits), \<lambda>_ obj. obj = (if dev then KOUserDataDevice else KOUserData))
       | n. n < 2 ^ (pageBitsForSize sz - pageBits) }"
| "aobj_relation_cuts (AARCH64_A.ASIDPool pool) x =
     {(x, other_obj_relation)}"
| "aobj_relation_cuts (PageTable pt) x =
     (\<lambda>y. (x + (y << pteBits), pte_relation y)) ` {0..mask (ptBits (pt_type pt))}"
| "aobj_relation_cuts (AARCH64_A.VCPU v) x =
     {(x, other_obj_relation)}"

primrec obj_relation_cuts :: "Structures_A.kernel_object \<Rightarrow> machine_word \<Rightarrow> obj_relation_cuts" where
  "obj_relation_cuts (CNode sz cs) x =
     (if well_formed_cnode_n sz cs
      then {(cte_map (x, y), cte_relation y) | y. y \<in> dom cs}
      else {(x, \<bottom>\<bottom>)})"
| "obj_relation_cuts (TCB tcb) x = {(x, other_obj_relation)}"
| "obj_relation_cuts (Endpoint ep) x = {(x, other_obj_relation)}"
| "obj_relation_cuts (Notification ntfn) x = {(x, other_obj_relation)}"
| "obj_relation_cuts (ArchObj ao) x = aobj_relation_cuts ao x"


lemma obj_relation_cuts_def2:
  "obj_relation_cuts ko x =
   (case ko of CNode sz cs \<Rightarrow> if well_formed_cnode_n sz cs
                              then {(cte_map (x, y), cte_relation y) | y. y \<in> dom cs}
                              else {(x, \<bottom>\<bottom>)}
             | ArchObj (PageTable pt) \<Rightarrow> (\<lambda>y. (x + (y << pteBits), pte_relation y)) ` {0..mask (ptBits (pt_type pt))}
             | ArchObj (DataPage dev sz) \<Rightarrow>
                 {(x + (n << pageBits),  \<lambda>_ obj. obj =(if dev then KOUserDataDevice else KOUserData))
                  | n . n < 2 ^ (pageBitsForSize sz - pageBits) }
             | _ \<Rightarrow> {(x, other_obj_relation)})"
  by (simp split: Structures_A.kernel_object.split
                  AARCH64_A.arch_kernel_obj.split)

lemma obj_relation_cuts_def3:
  "obj_relation_cuts ko x =
   (case a_type ko of
      ACapTable n \<Rightarrow> {(cte_map (x, y), cte_relation y) | y. length y = n}
    | AArch (APageTable pt_t) \<Rightarrow> (\<lambda>y. (x + (y << pteBits), pte_relation y)) ` {0..mask (ptBits pt_t)}
    | AArch (AUserData sz) \<Rightarrow> {(x + (n << pageBits), \<lambda>_ obj. obj = KOUserData)
                               | n . n < 2 ^ (pageBitsForSize sz - pageBits) }
    | AArch (ADeviceData sz) \<Rightarrow> {(x + (n << pageBits), \<lambda>_ obj. obj = KOUserDataDevice )
                                 | n . n < 2 ^ (pageBitsForSize sz - pageBits) }
    | AGarbage _ \<Rightarrow> {(x, \<bottom>\<bottom>)}
    | _ \<Rightarrow> {(x, other_obj_relation)})"
  by (simp add: obj_relation_cuts_def2 a_type_def well_formed_cnode_n_def length_set_helper
           split: Structures_A.kernel_object.split AARCH64_A.arch_kernel_obj.split)

definition is_other_obj_relation_type :: "a_type \<Rightarrow> bool" where
 "is_other_obj_relation_type tp \<equiv>
    case tp of
      ACapTable n \<Rightarrow> False
    | AArch (APageTable _) \<Rightarrow> False
    | AArch (AUserData _) \<Rightarrow> False
    | AArch (ADeviceData _) \<Rightarrow> False
    | AGarbage _ \<Rightarrow> False
    | _ \<Rightarrow> True"

lemma is_other_obj_relation_type_CapTable:
  "\<not> is_other_obj_relation_type (ACapTable n)"
  by (simp add: is_other_obj_relation_type_def)

lemma is_other_obj_relation_type_PageTable:
  "\<not> is_other_obj_relation_type (AArch (APageTable pt_t))"
  unfolding is_other_obj_relation_type_def by simp

lemma is_other_obj_relation_type_UserData:
  "\<not> is_other_obj_relation_type (AArch (AUserData sz))"
  unfolding is_other_obj_relation_type_def by simp

lemma is_other_obj_relation_type_DeviceData:
  "\<not> is_other_obj_relation_type (AArch (ADeviceData sz))"
  unfolding is_other_obj_relation_type_def by simp

lemma is_other_obj_relation_type:
  "is_other_obj_relation_type (a_type ko) \<Longrightarrow> obj_relation_cuts ko x = {(x, other_obj_relation)}"
  by (simp add: obj_relation_cuts_def3 is_other_obj_relation_type_def
           split: a_type.splits aa_type.splits)

definition pspace_dom :: "Structures_A.kheap \<Rightarrow> machine_word set" where
  "pspace_dom ps \<equiv> \<Union>x\<in>dom ps. fst ` (obj_relation_cuts (the (ps x)) x)"

definition pspace_relation ::
  "Structures_A.kheap \<Rightarrow> (machine_word \<rightharpoonup> Structures_H.kernel_object) \<Rightarrow> bool" where
  "pspace_relation ab con \<equiv>
     (pspace_dom ab = dom con) \<and>
     (\<forall>x \<in> dom ab. \<forall>(y, P) \<in> obj_relation_cuts (the (ab x)) x. P (the (ab x)) (the (con y)))"

definition etcb_relation :: "etcb \<Rightarrow> Structures_H.tcb \<Rightarrow> bool" where
  "etcb_relation \<equiv> \<lambda>etcb tcb'.
     tcb_priority etcb = tcbPriority tcb'
     \<and> tcb_time_slice etcb = tcbTimeSlice tcb'
     \<and> tcb_domain etcb = tcbDomain tcb'"

definition ekheap_relation ::
  "(obj_ref \<Rightarrow> etcb option) \<Rightarrow> (machine_word \<rightharpoonup> Structures_H.kernel_object) \<Rightarrow> bool" where
  "ekheap_relation ab con \<equiv>
     \<forall>x \<in> dom ab. \<exists>tcb'. con x = Some (KOTCB tcb') \<and> etcb_relation (the (ab x)) tcb'"

primrec sched_act_relation :: "Deterministic_A.scheduler_action \<Rightarrow> scheduler_action \<Rightarrow> bool"
  where
  "sched_act_relation resume_cur_thread a' = (a' = ResumeCurrentThread)" |
  "sched_act_relation choose_new_thread a' = (a' = ChooseNewThread)" |
  "sched_act_relation (switch_thread x) a' = (a' = SwitchToThread x)"

definition ready_queues_relation ::
  "(Deterministic_A.domain \<Rightarrow> Structures_A.priority \<Rightarrow> Deterministic_A.ready_queue) \<Rightarrow>
   (domain \<times> priority \<Rightarrow> KernelStateData_H.ready_queue) \<Rightarrow> bool" where
  "ready_queues_relation qs qs' \<equiv> \<forall>d p. (qs d p = qs' (d, p))"

definition ghost_relation ::
  "Structures_A.kheap \<Rightarrow> (machine_word \<rightharpoonup> vmpage_size) \<Rightarrow> (machine_word \<rightharpoonup> nat) \<Rightarrow> bool" where
  "ghost_relation h ups cns \<equiv>
     (\<forall>a sz. (\<exists>dev. h a = Some (ArchObj (DataPage dev sz))) \<longleftrightarrow> ups a = Some sz) \<and>
     (\<forall>a n. (\<exists>cs. h a = Some (CNode n cs) \<and> well_formed_cnode_n n cs) \<longleftrightarrow> cns a = Some n)"

definition cdt_relation :: "(cslot_ptr \<Rightarrow> bool) \<Rightarrow> cdt \<Rightarrow> cte_heap \<Rightarrow> bool" where
  "cdt_relation \<equiv> \<lambda>cte_at m m'.
     \<forall>c. cte_at c \<longrightarrow> cte_map ` descendants_of c m = descendants_of' (cte_map c) m'"

definition cdt_list_relation :: "cdt_list \<Rightarrow> cdt \<Rightarrow> cte_heap \<Rightarrow> bool" where
 "cdt_list_relation \<equiv> \<lambda>t m m'.
    \<forall>c cap node. m' (cte_map c) = Some (CTE cap node)
        \<longrightarrow> (case next_slot c t m of None \<Rightarrow> True
                                   | Some next \<Rightarrow> mdbNext node = cte_map next)"

definition revokable_relation ::
  "(cslot_ptr \<Rightarrow> bool) \<Rightarrow> (cslot_ptr \<Rightarrow> cap option) \<Rightarrow> cte_heap \<Rightarrow> bool" where
  "revokable_relation revo cs m' \<equiv>
     \<forall>c cap node. cs c \<noteq> None \<longrightarrow>
                    m' (cte_map c) = Some (CTE cap node) \<longrightarrow>
                    revo c = mdbRevocable node"

definition irq_state_relation :: "irq_state \<Rightarrow> irqstate \<Rightarrow> bool" where
  "irq_state_relation irq irq' \<equiv> case (irq, irq') of
     (irq_state.IRQInactive, irqstate.IRQInactive) \<Rightarrow> True
   | (irq_state.IRQSignal, irqstate.IRQSignal) \<Rightarrow> True
   | (irq_state.IRQTimer, irqstate.IRQTimer) \<Rightarrow> True
   | _ \<Rightarrow> False"

definition interrupt_state_relation ::
  "(irq \<Rightarrow> obj_ref) \<Rightarrow> (irq \<Rightarrow> irq_state) \<Rightarrow> interrupt_state \<Rightarrow> bool" where
  "interrupt_state_relation node_map irqs is \<equiv>
     (\<exists>node irqs'. is = InterruptState node irqs'
                    \<and> (\<forall>irq. node_map irq = node + (ucast irq << cte_level_bits))
                    \<and> (\<forall>irq. irq_state_relation (irqs irq) (irqs' irq)))"

definition arch_state_relation :: "(arch_state \<times> AARCH64_H.kernel_state) set" where
  "arch_state_relation \<equiv> {(s, s') .
         arm_asid_table s = armKSASIDTable s' \<circ> ucast
         \<and> arm_us_global_vspace s = armKSGlobalUserVSpace s'
         \<and> arm_next_vmid s = armKSNextVMID s'
         \<and> map_option ucast \<circ> arm_vmid_table s = armKSVMIDTable s'
         \<and> arm_kernel_vspace s = armKSKernelVSpace s'
         \<and> arm_current_vcpu s = armHSCurVCPU s'
         \<and> arm_gicvcpu_numlistregs s = armKSGICVCPUNumListRegs s'}"

definition rights_mask_map :: "rights set \<Rightarrow> Types_H.cap_rights" where
  "rights_mask_map \<equiv>
     \<lambda>rs. CapRights (AllowWrite \<in> rs) (AllowRead \<in> rs) (AllowGrant \<in> rs) (AllowGrantReply \<in> rs)"


lemma obj_relation_cutsE:
  "\<lbrakk> (y, P) \<in> obj_relation_cuts ko x; P ko ko';
     \<And>sz cs z cap cte. \<lbrakk> ko = CNode sz cs; well_formed_cnode_n sz cs; y = cte_map (x, z);
                         ko' = KOCTE cte; cs z = Some cap; cap_relation cap (cteCap cte) \<rbrakk>
              \<Longrightarrow> R;
     \<And>pt z pte'. \<lbrakk> ko = ArchObj (PageTable pt); y = x + (z << pteBits);
                   z \<le> mask (ptBits (pt_type pt)); ko' = KOArch (KOPTE pte');
                   pte_relation' (pt_apply pt z) pte' \<rbrakk>
              \<Longrightarrow> R;
     \<And>sz dev n. \<lbrakk> ko = ArchObj (DataPage dev sz);
                  ko' = (if dev then KOUserDataDevice else KOUserData);
                  y = x + (n << pageBits); n < 2 ^ (pageBitsForSize sz - pageBits) \<rbrakk> \<Longrightarrow> R;
            \<lbrakk> y = x; other_obj_relation ko ko'; is_other_obj_relation_type (a_type ko) \<rbrakk> \<Longrightarrow> R
    \<rbrakk> \<Longrightarrow> R"
  by (force simp: obj_relation_cuts_def2 is_other_obj_relation_type_def a_type_def
                  cte_relation_def pte_relation_def
            split: Structures_A.kernel_object.splits if_splits AARCH64_A.arch_kernel_obj.splits)

lemma eq_trans_helper:
  "\<lbrakk> x = y; P y = Q \<rbrakk> \<Longrightarrow> P x = Q"
  by simp

lemma cap_relation_case':
  "cap_relation cap cap' = (case cap of
                              cap.ArchObjectCap arch_cap.ASIDControlCap \<Rightarrow> cap_relation cap cap'
                            | _ \<Rightarrow> cap_relation cap cap')"
  by (simp split: cap.split arch_cap.split)

schematic_goal cap_relation_case:
  "cap_relation cap cap' = ?P"
  apply (subst cap_relation_case')
  apply (clarsimp cong: cap.case_cong arch_cap.case_cong)
  apply (rule refl)
  done

lemmas cap_relation_split =
  eq_trans_helper [where P=P, OF cap_relation_case cap.split[where P=P]] for P
lemmas cap_relation_split_asm =
  eq_trans_helper [where P=P, OF cap_relation_case cap.split_asm[where P=P]] for P



text \<open>
  Relations on other data types that aren't stored but used as intermediate values
  in the specs.
\<close>
primrec message_info_map :: "Structures_A.message_info \<Rightarrow> Types_H.message_info" where
  "message_info_map (Structures_A.MI a b c d) = (Types_H.MI a b c d)"

lemma mi_map_label[simp]: "msgLabel (message_info_map mi) = mi_label mi"
  by (cases mi, simp)

primrec syscall_error_map :: "ExceptionTypes_A.syscall_error \<Rightarrow> Fault_H.syscall_error" where
  "syscall_error_map (ExceptionTypes_A.InvalidArgument n)   = Fault_H.InvalidArgument n"
| "syscall_error_map (ExceptionTypes_A.InvalidCapability n) = (Fault_H.InvalidCapability n)"
| "syscall_error_map ExceptionTypes_A.IllegalOperation      = Fault_H.IllegalOperation"
| "syscall_error_map (ExceptionTypes_A.RangeError n m)      = Fault_H.RangeError n m"
| "syscall_error_map ExceptionTypes_A.AlignmentError        = Fault_H.AlignmentError"
| "syscall_error_map (ExceptionTypes_A.FailedLookup b lf)   = Fault_H.FailedLookup b (lookup_failure_map lf)"
| "syscall_error_map ExceptionTypes_A.TruncatedMessage      = Fault_H.TruncatedMessage"
| "syscall_error_map ExceptionTypes_A.DeleteFirst           = Fault_H.DeleteFirst"
| "syscall_error_map ExceptionTypes_A.RevokeFirst           = Fault_H.RevokeFirst"
| "syscall_error_map (ExceptionTypes_A.NotEnoughMemory n)   = Fault_H.syscall_error.NotEnoughMemory n"

definition APIType_map :: "Structures_A.apiobject_type \<Rightarrow> AARCH64_H.object_type" where
  "APIType_map ty \<equiv>
     case ty of
       Structures_A.Untyped \<Rightarrow> APIObjectType ArchTypes_H.Untyped
     | Structures_A.TCBObject \<Rightarrow> APIObjectType ArchTypes_H.TCBObject
     | Structures_A.EndpointObject \<Rightarrow> APIObjectType ArchTypes_H.EndpointObject
     | Structures_A.NotificationObject \<Rightarrow> APIObjectType ArchTypes_H.NotificationObject
     | Structures_A.CapTableObject \<Rightarrow> APIObjectType ArchTypes_H.CapTableObject
     | ArchObject ao \<Rightarrow> (case ao of
                           SmallPageObj \<Rightarrow> SmallPageObject
                         | LargePageObj \<Rightarrow> LargePageObject
                         | HugePageObj  \<Rightarrow> HugePageObject
                         | PageTableObj \<Rightarrow> PageTableObject
                         | AARCH64_A.VCPUObj \<Rightarrow> VCPUObject)"

definition state_relation :: "(det_state \<times> kernel_state) set" where
  "state_relation \<equiv> {(s, s').
         pspace_relation (kheap s) (ksPSpace s')
       \<and> ekheap_relation (ekheap s) (ksPSpace s')
       \<and> sched_act_relation (scheduler_action s) (ksSchedulerAction s')
       \<and> ready_queues_relation (ready_queues s) (ksReadyQueues s')
       \<and> ghost_relation (kheap s) (gsUserPages s') (gsCNodes s')
       \<and> cdt_relation (swp cte_at s) (cdt s) (ctes_of s')
       \<and> cdt_list_relation (cdt_list s) (cdt s) (ctes_of s')
       \<and> revokable_relation (is_original_cap s) (null_filter (caps_of_state s)) (ctes_of s')
       \<and> (arch_state s, ksArchState s') \<in> arch_state_relation
       \<and> interrupt_state_relation (interrupt_irq_node s) (interrupt_states s) (ksInterruptState s')
       \<and> (cur_thread s = ksCurThread s')
       \<and> (idle_thread s = ksIdleThread s')
       \<and> (machine_state s = ksMachineState s')
       \<and> (work_units_completed s = ksWorkUnitsCompleted s')
       \<and> (domain_index s = ksDomScheduleIdx s')
       \<and> (domain_list s = ksDomSchedule s')
       \<and> (cur_domain s = ksCurDomain s')
       \<and> (domain_time s = ksDomainTime s')}"

text \<open>Rules for using states in the relation.\<close>

lemma curthread_relation:
  "(a, b) \<in> state_relation \<Longrightarrow> ksCurThread b = cur_thread a"
  by (simp add: state_relation_def)

lemma state_relation_pspace_relation[elim!]:
  "(s,s') \<in> state_relation \<Longrightarrow> pspace_relation (kheap s) (ksPSpace s')"
  by (simp add: state_relation_def)

lemma state_relation_ekheap_relation[elim!]:
  "(s,s') \<in> state_relation \<Longrightarrow> ekheap_relation (ekheap s) (ksPSpace s')"
  by (simp add: state_relation_def)

lemma state_relationD:
  "(s, s') \<in> state_relation \<Longrightarrow>
   pspace_relation (kheap s) (ksPSpace s') \<and>
   ekheap_relation (ekheap s) (ksPSpace s') \<and>
   sched_act_relation (scheduler_action s) (ksSchedulerAction s') \<and>
   ready_queues_relation (ready_queues s) (ksReadyQueues s') \<and>
   ghost_relation (kheap s) (gsUserPages s') (gsCNodes s') \<and>
   cdt_relation (swp cte_at s) (cdt s) (ctes_of s') \<and>
   cdt_list_relation (cdt_list s) (cdt s) (ctes_of s') \<and>
   revokable_relation (is_original_cap s) (null_filter (caps_of_state s)) (ctes_of s') \<and>
   (arch_state s, ksArchState s') \<in> arch_state_relation \<and>
   interrupt_state_relation (interrupt_irq_node s) (interrupt_states s) (ksInterruptState s') \<and>
   cur_thread s = ksCurThread s' \<and>
   idle_thread s = ksIdleThread s' \<and>
   machine_state s = ksMachineState s' \<and>
   work_units_completed s = ksWorkUnitsCompleted s' \<and>
   domain_index s = ksDomScheduleIdx s' \<and>
   domain_list s = ksDomSchedule s' \<and>
   cur_domain s = ksCurDomain s' \<and>
   domain_time s = ksDomainTime s'"
  unfolding state_relation_def by simp

lemma state_relationE [elim?]:
  assumes sr:  "(s, s') \<in> state_relation"
  and rl: "\<lbrakk> pspace_relation (kheap s) (ksPSpace s');
             ekheap_relation (ekheap s) (ksPSpace s');
             sched_act_relation (scheduler_action s) (ksSchedulerAction s');
             ready_queues_relation (ready_queues s) (ksReadyQueues s');
             ghost_relation (kheap s) (gsUserPages s') (gsCNodes s');
             cdt_relation (swp cte_at s) (cdt s) (ctes_of s') \<and>
             revokable_relation (is_original_cap s) (null_filter (caps_of_state s)) (ctes_of s');
             cdt_list_relation (cdt_list s) (cdt s) (ctes_of s');
             (arch_state s, ksArchState s') \<in> arch_state_relation;
             interrupt_state_relation (interrupt_irq_node s) (interrupt_states s) (ksInterruptState s');
             cur_thread s = ksCurThread s';
             idle_thread s = ksIdleThread s';
             machine_state s = ksMachineState s';
             work_units_completed s = ksWorkUnitsCompleted s';
             domain_index s = ksDomScheduleIdx s';
             domain_list s = ksDomSchedule s';
             cur_domain s = ksCurDomain s';
             domain_time s = ksDomainTime s' \<rbrakk> \<Longrightarrow> R"
  shows "R"
  using sr by (blast intro!: rl dest: state_relationD)

lemmas isCap_defs =
  isZombie_def isArchObjectCap_def
  isThreadCap_def isCNodeCap_def isNotificationCap_def
  isEndpointCap_def isUntypedCap_def isNullCap_def
  isIRQHandlerCap_def isIRQControlCap_def isReplyCap_def
  isFrameCap_def isPageTableCap_def
  isASIDControlCap_def isASIDPoolCap_def
  isDomainCap_def isArchFrameCap_def isVCPUCap_def

lemma isCNodeCap_cap_map[simp]:
  "cap_relation c c' \<Longrightarrow> isCNodeCap c' = is_cnode_cap c"
  by (cases c) (auto simp: isCap_defs split: sum.splits)

lemma sts_rel_idle :
  "thread_state_relation st IdleThreadState = (st = Structures_A.IdleThreadState)"
  by (cases st, auto)

lemma pspace_relation_absD:
  "\<lbrakk> ab x = Some y; pspace_relation ab con \<rbrakk>
      \<Longrightarrow> \<forall>(x', P) \<in> obj_relation_cuts y x. \<exists>z. con x' = Some z \<and> P y z"
  apply (clarsimp simp: pspace_relation_def)
  apply (drule bspec, erule domI)
  apply simp
  apply (drule(1) bspec)
  apply (subgoal_tac "a \<in> pspace_dom ab", clarsimp)
  apply (simp (no_asm) add: pspace_dom_def)
  apply (fastforce simp: image_def intro: rev_bexI)
  done

lemma ekheap_relation_absD:
  "\<lbrakk> ab x = Some y; ekheap_relation ab con \<rbrakk> \<Longrightarrow>
   \<exists>tcb'. con x = Some (KOTCB tcb') \<and> etcb_relation y tcb'"
  by (force simp add: ekheap_relation_def)

lemma in_related_pspace_dom:
  "\<lbrakk> s' x = Some y; pspace_relation s s' \<rbrakk> \<Longrightarrow> x \<in> pspace_dom s"
  by (clarsimp simp add: pspace_relation_def)

lemma pspace_dom_revE:
  "\<lbrakk> x \<in> pspace_dom ps; \<And>ko y P. \<lbrakk> ps y = Some ko; (x, P) \<in> obj_relation_cuts ko y \<rbrakk> \<Longrightarrow> R \<rbrakk> \<Longrightarrow> R"
  by (clarsimp simp add: pspace_dom_def)

lemma pspace_dom_relatedE:
  "\<lbrakk> s' x = Some ko'; pspace_relation s s';
     \<And>y ko P. \<lbrakk> s y = Some ko; (x, P) \<in> obj_relation_cuts ko y; P ko ko' \<rbrakk> \<Longrightarrow> R \<rbrakk> \<Longrightarrow> R"
  apply (rule pspace_dom_revE [OF in_related_pspace_dom]; assumption?)
  apply (fastforce dest: pspace_relation_absD)
  done

lemma ghost_relation_typ_at:
  "ghost_relation (kheap s) ups cns \<equiv>
     (\<forall>a sz. data_at sz a s = (ups a = Some sz)) \<and>
     (\<forall>a n. typ_at (ACapTable n) a s = (cns a = Some n))"
  apply (rule eq_reflection)
  apply (clarsimp simp: ghost_relation_def typ_at_eq_kheap_obj data_at_def)
  apply (intro conjI impI iffI allI; force)
  done

end

end
