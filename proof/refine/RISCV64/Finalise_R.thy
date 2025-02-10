(*
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

theory Finalise_R
imports
  IpcCancel_R
  InterruptAcc_R
  Retype_R
begin

context begin interpretation Arch . (*FIXME: arch-split*)

declare doUnbindNotification_def[simp]

crunch copyGlobalMappings
  for ifunsafe'[wp]: "if_unsafe_then_cap'"
  and pred_tcb_at'[wp]: "pred_tcb_at' proj P t"
  and vms'[wp]: "valid_machine_state'"
  and ct_not_inQ[wp]: "ct_not_inQ"
  and tcb_in_cur_domain'[wp]: "tcb_in_cur_domain' t"
  and ct__in_cur_domain'[wp]: ct_idle_or_in_cur_domain'
  and gsUntypedZeroRanges[wp]: "\<lambda>s. P (gsUntypedZeroRanges s)"
  and gsMaxObjectSize[wp]: "\<lambda>s. P (gsMaxObjectSize s)"
  and valid_irq_states'[wp]: "valid_irq_states'"
  and ksDomScheduleIdx[wp]: "\<lambda>s. P (ksDomScheduleIdx s)"
  (wp: crunch_wps ignore: storePTE)

text \<open>Properties about empty_slot/emptySlot\<close>

lemma case_Null_If:
  "(case c of NullCap \<Rightarrow> a | _ \<Rightarrow> b) = (if c = NullCap then a else b)"
  by (case_tac c, simp_all)

crunch emptySlot
  for aligned'[wp]: pspace_aligned'
  and pspace_canonical'[wp]: pspace_canonical'
  and pspace_in_kernel_mappings'[wp]: pspace_in_kernel_mappings'
  and distinct'[wp]: pspace_distinct'
  (simp: case_Null_If)

lemma updateCap_cte_wp_at_cases:
  "\<lbrace>\<lambda>s. (ptr = ptr' \<longrightarrow> cte_wp_at' (P \<circ> cteCap_update (K cap)) ptr' s) \<and> (ptr \<noteq> ptr' \<longrightarrow> cte_wp_at' P ptr' s)\<rbrace>
     updateCap ptr cap
   \<lbrace>\<lambda>rv. cte_wp_at' P ptr'\<rbrace>"
  apply (clarsimp simp: valid_def)
  apply (drule updateCap_stuff)
  apply (clarsimp simp: cte_wp_at_ctes_of modify_map_def)
  done

crunch postCapDeletion, updateTrackedFreeIndex
  for cte_wp_at'[wp]: "cte_wp_at' P p"

end

lemma updateFreeIndex_cte_wp_at:
  "\<lbrace>\<lambda>s. cte_at' p s \<and> P (cte_wp_at' (if p = p' then P'
      o (cteCap_update (capFreeIndex_update (K idx))) else P') p' s)\<rbrace>
    updateFreeIndex p idx
  \<lbrace>\<lambda>rv s. P (cte_wp_at' P' p' s)\<rbrace>"
  apply (simp add: updateFreeIndex_def updateTrackedFreeIndex_def
        split del: if_split)
  apply (rule hoare_pre)
   apply (wp updateCap_cte_wp_at' getSlotCap_wp)
  apply (clarsimp simp: cte_wp_at_ctes_of)
  apply (cases "p' = p", simp_all)
  apply (case_tac cte, simp)
  done

lemma emptySlot_cte_wp_cap_other:
  "\<lbrace>(\<lambda>s. cte_wp_at' (\<lambda>c. P (cteCap c)) p s) and K (p \<noteq> p')\<rbrace>
  emptySlot p' opt
  \<lbrace>\<lambda>rv s. cte_wp_at' (\<lambda>c. P (cteCap c)) p s\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (simp add: emptySlot_def clearUntypedFreeIndex_def getSlotCap_def)
  apply (rule hoare_pre)
   apply (wp updateMDB_weak_cte_wp_at updateCap_cte_wp_at_cases
             updateFreeIndex_cte_wp_at getCTE_wp' hoare_vcg_all_lift
              | simp add:  | wpc
              | wp (once) hoare_drop_imps)+
  done

crunch clearUntypedFreeIndex
  for sc_at'_n[wp]: "\<lambda>s. P (sc_at'_n n p s)"

global_interpretation clearUntypedFreeIndex: typ_at_all_props' "clearUntypedFreeIndex slot"
  by typ_at_props'

context begin interpretation Arch . (*FIXME: arch-split*)

crunch postCapDeletion
  for tcb_at'[wp]: "tcb_at' t"
crunch emptySlot
  for ct[wp]: "\<lambda>s. P (ksCurThread s)"
crunch clearUntypedFreeIndex
  for cur_tcb'[wp]: "cur_tcb'"
  (wp: cur_tcb_lift)

crunch emptySlot
  for ksRQ[wp]: "\<lambda>s. P (ksReadyQueues s)"
  and ksRLQ[wp]: "\<lambda>s. P (ksReleaseQueue s)"
  and ksRQL1[wp]: "\<lambda>s. P (ksReadyQueuesL1Bitmap s)"
  and ksRQL2[wp]: "\<lambda>s. P (ksReadyQueuesL2Bitmap s)"
  and tcbSchedNexts_of[wp]: "\<lambda>s. P (tcbSchedNexts_of s)"
  and tcbSchedPrevs_of[wp]: "\<lambda>s. P (tcbSchedPrevs_of s)"
  and inQ_tcbs_of'[wp]: "\<lambda>s. P (inQ d p |< tcbs_of' s)"
  and tcbDomain[wp]: "obj_at' (\<lambda>tcb. P (tcbDomain tcb)) t"

crunch clearUntypedFreeIndex
 for inQ[wp]: "\<lambda>s. P (obj_at' (inQ d p) t s)"
crunch clearUntypedFreeIndex
 for tcbInReleaseQueue_obj_at'[wp]: "\<lambda>s. P (obj_at' tcbInReleaseQueue t s)"
crunch clearUntypedFreeIndex
 for tcbDomain[wp]: "obj_at' (\<lambda>tcb. P (tcbDomain tcb)) t"
crunch clearUntypedFreeIndex
 for tcbPriority[wp]: "obj_at' (\<lambda>tcb. P (tcbPriority tcb)) t"
crunch clearUntypedFreeIndex
 for tcbQueued[wp]: "obj_at' (\<lambda>tcb. P (tcbQueued tcb)) t"

crunch emptySlot
  for tcbInReleaseQueue[wp]: "\<lambda>s. P (tcbInReleaseQueue |< tcbs_of' s)"
  and sym_heap_sched_pointers[wp]: sym_heap_sched_pointers

crunch emptySlot
  for nosch[wp]: "\<lambda>s. P (ksSchedulerAction s)"
crunch emptySlot
  for ksCurDomain[wp]: "\<lambda>s. P (ksCurDomain s)"

lemma updateCap_valid_objs' [wp]:
  "\<lbrace>valid_objs' and valid_cap' cap\<rbrace>
  updateCap ptr cap \<lbrace>\<lambda>r. valid_objs'\<rbrace>"
  unfolding updateCap_def
  by (wp setCTE_valid_objs getCTE_wp) (clarsimp dest!: cte_at_cte_wp_atD)

lemma updateFreeIndex_valid_objs' [wp]:
  "\<lbrace>valid_objs'\<rbrace> clearUntypedFreeIndex ptr \<lbrace>\<lambda>r. valid_objs'\<rbrace>"
  apply (simp add: clearUntypedFreeIndex_def getSlotCap_def)
  apply (wp getCTE_wp' | wpc | simp add: updateTrackedFreeIndex_def)+
  done

crunch emptySlot
  for valid_objs'[wp]: "valid_objs'"

crunch setInterruptState
  for state_refs_of'[wp]: "\<lambda>s. P (state_refs_of' s)"
  (simp: state_refs_of'_pspaceI)
crunch emptySlot
  for state_refs_of'[wp]: "\<lambda>s. P (state_refs_of' s)"
  (wp: crunch_wps)

lemma mdb_chunked2D:
  "\<lbrakk> mdb_chunked m; m \<turnstile> p \<leadsto> p'; m \<turnstile> p' \<leadsto> p'';
     m p = Some (CTE cap nd); m p'' = Some (CTE cap'' nd'');
     sameRegionAs cap cap''; p \<noteq> p'' \<rbrakk>
     \<Longrightarrow> \<exists>cap' nd'. m p' = Some (CTE cap' nd') \<and> sameRegionAs cap cap'"
  apply (subgoal_tac "\<exists>cap' nd'. m p' = Some (CTE cap' nd')")
   apply (clarsimp simp add: mdb_chunked_def)
   apply (drule spec[where x=p])
   apply (drule spec[where x=p''])
   apply clarsimp
   apply (drule mp, erule trancl_into_trancl2)
    apply (erule trancl.intros(1))
   apply (simp add: is_chunk_def)
   apply (drule spec, drule mp, erule trancl.intros(1))
   apply (drule mp, rule trancl_into_rtrancl)
    apply (erule trancl.intros(1))
   apply clarsimp
  apply (clarsimp simp: mdb_next_unfold)
  apply (case_tac z, simp)
  done

lemma nullPointer_eq_0_simp[simp]:
  "(0 = nullPointer) = True"
  by (simp add: nullPointer_def)

lemma no_0_no_0_lhs_trancl [simp]:
  "no_0 m \<Longrightarrow> \<not> m \<turnstile> 0 \<leadsto>\<^sup>+ x"
  by (rule, drule tranclD, clarsimp simp: next_unfold')

lemma no_0_no_0_lhs_rtrancl [simp]:
  "\<lbrakk> no_0 m; x \<noteq> 0 \<rbrakk> \<Longrightarrow> \<not> m \<turnstile> 0 \<leadsto>\<^sup>* x"
  by (clarsimp dest!: rtranclD)

end
locale mdb_empty =
  mdb_ptr?: mdb_ptr m _ _ slot s_cap s_node
    for m slot s_cap s_node +

  fixes n
  defines "n \<equiv>
           modify_map
             (modify_map
               (modify_map
                 (modify_map m (mdbPrev s_node)
                   (cteMDBNode_update (mdbNext_update (%_. (mdbNext s_node)))))
                 (mdbNext s_node)
                 (cteMDBNode_update
                   (\<lambda>mdb. mdbFirstBadged_update (%_. (mdbFirstBadged mdb \<or> mdbFirstBadged s_node))
                           (mdbPrev_update (%_. (mdbPrev s_node)) mdb))))
               slot (cteCap_update (%_. capability.NullCap)))
              slot (cteMDBNode_update (const nullMDBNode))"
begin
interpretation Arch . (*FIXME: arch-split*)

lemmas m_slot_prev = m_p_prev
lemmas m_slot_next = m_p_next
lemmas prev_slot_next = prev_p_next
lemmas next_slot_prev = next_p_prev

lemma n_revokable:
  "n p = Some (CTE cap node) \<Longrightarrow>
  (\<exists>cap' node'. m p = Some (CTE cap' node') \<and>
              (if p = slot
               then \<not> mdbRevocable node
               else mdbRevocable node = mdbRevocable node'))"
  by (auto simp add: n_def modify_map_if nullMDBNode_def split: if_split_asm)

lemma m_revokable:
  "m p = Some (CTE cap node) \<Longrightarrow>
  (\<exists>cap' node'. n p = Some (CTE cap' node') \<and>
              (if p = slot
               then \<not> mdbRevocable node'
               else mdbRevocable node' = mdbRevocable node))"
  apply (clarsimp simp add: n_def modify_map_if nullMDBNode_def split: if_split_asm)
  apply (cases "p=slot", simp)
  apply (cases "p=mdbNext s_node", simp)
   apply (cases "p=mdbPrev s_node", simp)
   apply clarsimp
  apply simp
  apply (cases "p=mdbPrev s_node", simp)
  apply simp
  done

lemma no_0_n:
  "no_0 n"
  using no_0 by (simp add: n_def)

lemma n_next:
  "n p = Some (CTE cap node) \<Longrightarrow>
  (\<exists>cap' node'. m p = Some (CTE cap' node') \<and>
              (if p = slot
               then mdbNext node = 0
               else if p = mdbPrev s_node
               then mdbNext node = mdbNext s_node
               else mdbNext node = mdbNext node'))"
  apply (subgoal_tac "p \<noteq> 0")
   prefer 2
   apply (insert no_0_n)[1]
   apply clarsimp
  apply (cases "p = slot")
   apply (clarsimp simp: n_def modify_map_if initMDBNode_def split: if_split_asm)
  apply (cases "p = mdbPrev s_node")
   apply (auto simp: n_def modify_map_if initMDBNode_def split: if_split_asm)
  done

lemma n_prev:
  "n p = Some (CTE cap node) \<Longrightarrow>
  (\<exists>cap' node'. m p = Some (CTE cap' node') \<and>
              (if p = slot
               then mdbPrev node = 0
               else if p = mdbNext s_node
               then mdbPrev node = mdbPrev s_node
               else mdbPrev node = mdbPrev node'))"
  apply (subgoal_tac "p \<noteq> 0")
   prefer 2
   apply (insert no_0_n)[1]
   apply clarsimp
  apply (cases "p = slot")
   apply (clarsimp simp: n_def modify_map_if initMDBNode_def split: if_split_asm)
  apply (cases "p = mdbNext s_node")
   apply (auto simp: n_def modify_map_if initMDBNode_def split: if_split_asm)
  done

lemma n_cap:
  "n p = Some (CTE cap node) \<Longrightarrow>
  \<exists>cap' node'. m p = Some (CTE cap' node') \<and>
              (if p = slot
               then cap = NullCap
               else cap' = cap)"
  apply (clarsimp simp: n_def modify_map_if initMDBNode_def split: if_split_asm)
   apply (cases node)
   apply auto
  done

lemma m_cap:
  "m p = Some (CTE cap node) \<Longrightarrow>
  \<exists>cap' node'. n p = Some (CTE cap' node') \<and>
              (if p = slot
               then cap' = NullCap
               else cap' = cap)"
  apply (clarsimp simp: n_def modify_map_cases initMDBNode_def)
  apply (cases node)
  apply clarsimp
  apply (cases "p=slot", simp)
  apply clarsimp
  apply (cases "mdbNext s_node = p", simp)
   apply fastforce
  apply simp
  apply (cases "mdbPrev s_node = p", simp)
  apply fastforce
  done

lemma n_badged:
  "n p = Some (CTE cap node) \<Longrightarrow>
  \<exists>cap' node'. m p = Some (CTE cap' node') \<and>
              (if p = slot
               then \<not> mdbFirstBadged node
               else if p = mdbNext s_node
               then mdbFirstBadged node = (mdbFirstBadged node' \<or> mdbFirstBadged s_node)
               else mdbFirstBadged node = mdbFirstBadged node')"
  apply (subgoal_tac "p \<noteq> 0")
   prefer 2
   apply (insert no_0_n)[1]
   apply clarsimp
  apply (cases "p = slot")
   apply (clarsimp simp: n_def modify_map_if initMDBNode_def split: if_split_asm)
  apply (cases "p = mdbNext s_node")
   apply (auto simp: n_def modify_map_if nullMDBNode_def split: if_split_asm)
  done

lemma m_badged:
  "m p = Some (CTE cap node) \<Longrightarrow>
  \<exists>cap' node'. n p = Some (CTE cap' node') \<and>
              (if p = slot
               then \<not> mdbFirstBadged node'
               else if p = mdbNext s_node
               then mdbFirstBadged node' = (mdbFirstBadged node \<or> mdbFirstBadged s_node)
               else mdbFirstBadged node' = mdbFirstBadged node)"
  apply (subgoal_tac "p \<noteq> 0")
   prefer 2
   apply (insert no_0_n)[1]
   apply clarsimp
  apply (cases "p = slot")
   apply (clarsimp simp: n_def modify_map_if nullMDBNode_def split: if_split_asm)
  apply (cases "p = mdbNext s_node")
   apply (clarsimp simp: n_def modify_map_if nullMDBNode_def split: if_split_asm)
  apply clarsimp
  apply (cases "p = mdbPrev s_node")
   apply (auto simp: n_def modify_map_if initMDBNode_def  split: if_split_asm)
  done

lemmas slot = m_p

lemma m_next:
  "m p = Some (CTE cap node) \<Longrightarrow>
  \<exists>cap' node'. n p = Some (CTE cap' node') \<and>
              (if p = slot
               then mdbNext node' = 0
               else if p = mdbPrev s_node
               then mdbNext node' = mdbNext s_node
               else mdbNext node' = mdbNext node)"
  apply (subgoal_tac "p \<noteq> 0")
   prefer 2
   apply clarsimp
  apply (cases "p = slot")
   apply (clarsimp simp: n_def modify_map_if)
  apply (cases "p = mdbPrev s_node")
   apply (simp add: n_def modify_map_if)
  apply simp
  apply (simp add: n_def modify_map_if)
  apply (cases "mdbNext s_node = p")
   apply fastforce
  apply fastforce
  done

lemma m_prev:
  "m p = Some (CTE cap node) \<Longrightarrow>
  \<exists>cap' node'. n p = Some (CTE cap' node') \<and>
              (if p = slot
               then mdbPrev node' = 0
               else if p = mdbNext s_node
               then mdbPrev node' = mdbPrev s_node
               else mdbPrev node' = mdbPrev node)"
  apply (subgoal_tac "p \<noteq> 0")
   prefer 2
   apply clarsimp
  apply (cases "p = slot")
   apply (clarsimp simp: n_def modify_map_if)
  apply (cases "p = mdbPrev s_node")
   apply (simp add: n_def modify_map_if)
  apply simp
  apply (simp add: n_def modify_map_if)
  apply (cases "mdbNext s_node = p")
   apply fastforce
  apply fastforce
  done

lemma n_nextD:
  "n \<turnstile> p \<leadsto> p' \<Longrightarrow>
  if p = slot then p' = 0
  else if p = mdbPrev s_node
  then m \<turnstile> p \<leadsto> slot \<and> p' = mdbNext s_node
  else m \<turnstile> p \<leadsto> p'"
  apply (clarsimp simp: mdb_next_unfold split del: if_split cong: if_cong)
  apply (case_tac z)
  apply (clarsimp split del: if_split)
  apply (drule n_next)
  apply (elim exE conjE)
  apply (simp split: if_split_asm)
  apply (frule dlist_prevD [OF m_slot_prev])
  apply (clarsimp simp: mdb_next_unfold)
  done

lemma n_next_eq:
  "n \<turnstile> p \<leadsto> p' =
  (if p = slot then p' = 0
  else if p = mdbPrev s_node
  then m \<turnstile> p \<leadsto> slot \<and> p' = mdbNext s_node
  else m \<turnstile> p \<leadsto> p')"
  apply (rule iffI)
   apply (erule n_nextD)
  apply (clarsimp simp: mdb_next_unfold split: if_split_asm)
    apply (simp add: n_def modify_map_if slot)
   apply hypsubst_thin
   apply (case_tac z)
   apply simp
   apply (drule m_next)
   apply clarsimp
  apply (case_tac z)
  apply simp
  apply (drule m_next)
  apply clarsimp
  done

lemma n_prev_eq:
  "n \<turnstile> p \<leftarrow> p' =
  (if p' = slot then p = 0
  else if p' = mdbNext s_node
  then m \<turnstile> slot \<leftarrow> p' \<and> p = mdbPrev s_node
  else m \<turnstile> p \<leftarrow> p')"
  apply (rule iffI)
   apply (clarsimp simp: mdb_prev_def split del: if_split cong: if_cong)
   apply (case_tac z)
   apply (clarsimp split del: if_split)
   apply (drule n_prev)
   apply (elim exE conjE)
   apply (simp split: if_split_asm)
   apply (frule dlist_nextD [OF m_slot_next])
   apply (clarsimp simp: mdb_prev_def)
  apply (clarsimp simp: mdb_prev_def split: if_split_asm)
    apply (simp add: n_def modify_map_if slot)
   apply hypsubst_thin
   apply (case_tac z)
   apply clarsimp
   apply (drule m_prev)
   apply clarsimp
  apply (case_tac z)
  apply simp
  apply (drule m_prev)
  apply clarsimp
  done

lemma valid_dlist_n:
  "valid_dlist n" using dlist
  apply (clarsimp simp: valid_dlist_def2 [OF no_0_n])
  apply (simp add: n_next_eq n_prev_eq m_slot_next m_slot_prev cong: if_cong)
  apply (rule conjI, clarsimp)
   apply (rule conjI, clarsimp simp: next_slot_prev prev_slot_next)
   apply (fastforce dest!: dlist_prev_src_unique)
  apply clarsimp
  apply (rule conjI, clarsimp)
   apply (clarsimp simp: valid_dlist_def2 [OF no_0])
   apply (case_tac "mdbNext s_node = 0")
    apply simp
    apply (subgoal_tac "m \<turnstile> slot \<leadsto> c'")
     prefer 2
     apply fastforce
    apply (clarsimp simp: mdb_next_unfold slot)
   apply (frule next_slot_prev)
   apply (drule (1) dlist_prev_src_unique, simp)
   apply simp
  apply clarsimp
  apply (rule conjI, clarsimp)
   apply (fastforce dest: dlist_next_src_unique)
  apply clarsimp
  apply (rule conjI, clarsimp)
   apply (clarsimp simp: valid_dlist_def2 [OF no_0])
   apply (clarsimp simp: mdb_prev_def slot)
  apply (clarsimp simp: valid_dlist_def2 [OF no_0])
  done

lemma caps_contained_n:
  "caps_contained' n"
  using valid
  apply (clarsimp simp: valid_mdb_ctes_def caps_contained'_def)
  apply (drule n_cap)+
  apply (clarsimp split: if_split_asm)
  apply (erule disjE, clarsimp)
  apply clarsimp
  apply fastforce
  done

lemma chunked:
  "mdb_chunked m"
  using valid by (simp add: valid_mdb_ctes_def)

lemma valid_badges:
  "valid_badges m"
  using valid ..

lemma valid_badges_n:
  "valid_badges n"
proof -
  from valid_badges
  show ?thesis
    apply (simp add: valid_badges_def2)
    apply clarsimp
    apply (drule_tac p=p in n_cap)
    apply (frule n_cap)
    apply (drule n_badged)
    apply (clarsimp simp: n_next_eq)
    apply (case_tac "p=slot", simp)
    apply clarsimp
    apply (case_tac "p'=slot", simp)
    apply clarsimp
    apply (case_tac "p = mdbPrev s_node")
     apply clarsimp
     apply (insert slot)[1]
     (* using mdb_chunked to show cap in between is same as on either side *)
     apply (subgoal_tac "capMasterCap s_cap = capMasterCap cap'")
      prefer 2
      apply (thin_tac "\<forall>p. P p" for P)
      apply (drule mdb_chunked2D[OF chunked])
           apply (fastforce simp: mdb_next_unfold)
          apply assumption+
        apply (simp add: sameRegionAs_def3)
        apply (intro disjI1)
        apply (fastforce simp:isCap_simps capMasterCap_def split:capability.splits)
       apply clarsimp
      apply clarsimp
      apply (erule sameRegionAsE, auto simp: isCap_simps capMasterCap_def split:capability.splits)[1]
     (* instantiating known valid_badges on both sides to transitively
        give the link we need *)
     apply (frule_tac x="mdbPrev s_node" in spec)
     apply simp
     apply (drule spec, drule spec, drule spec,
            drule(1) mp, drule(1) mp)
     apply simp
     apply (drule_tac x=slot in spec)
     apply (drule_tac x="mdbNext s_node" in spec)
     apply simp
     apply (drule mp, simp(no_asm) add: mdb_next_unfold)
      apply simp
     apply (cases "capBadge s_cap", simp_all)[1]
    apply clarsimp
    apply (case_tac "p' = mdbNext s_node")
     apply clarsimp
     apply (frule vdlist_next_src_unique[where y=slot])
        apply (simp add: mdb_next_unfold slot)
       apply clarsimp
      apply (rule dlist)
     apply clarsimp
    apply clarsimp
    apply fastforce
    done
qed

lemma to_slot_eq [simp]:
  "m \<turnstile> p \<leadsto> slot = (p = mdbPrev s_node \<and> p \<noteq> 0)"
  apply (rule iffI)
   apply (frule dlist_nextD0, simp)
   apply (clarsimp simp: mdb_prev_def slot mdb_next_unfold)
  apply (clarsimp intro!: prev_slot_next)
  done

lemma n_parent_of:
  "\<lbrakk> n \<turnstile> p parentOf p'; p \<noteq> slot; p' \<noteq> slot \<rbrakk> \<Longrightarrow> m \<turnstile> p parentOf p'"
  apply (clarsimp simp: parentOf_def)
  apply (case_tac cte, case_tac cte')
  apply clarsimp
  apply (frule_tac p=p in n_cap)
  apply (frule_tac p=p in n_badged)
  apply (drule_tac p=p in n_revokable)
  apply (clarsimp)
  apply (frule_tac p=p' in n_cap)
  apply (frule_tac p=p' in n_badged)
  apply (drule_tac p=p' in n_revokable)
  apply (clarsimp split: if_split_asm;
         clarsimp simp: isMDBParentOf_def isCap_simps split: if_split_asm cong: if_cong)
  done

lemma m_parent_of:
  "\<lbrakk> m \<turnstile> p parentOf p'; p \<noteq> slot; p' \<noteq> slot; p\<noteq>p'; p'\<noteq>mdbNext s_node \<rbrakk> \<Longrightarrow> n \<turnstile> p parentOf p'"
  apply (clarsimp simp add: parentOf_def)
  apply (case_tac cte, case_tac cte')
  apply clarsimp
  apply (frule_tac p=p in m_cap)
  apply (frule_tac p=p in m_badged)
  apply (drule_tac p=p in m_revokable)
  apply clarsimp
  apply (frule_tac p=p' in m_cap)
  apply (frule_tac p=p' in m_badged)
  apply (drule_tac p=p' in m_revokable)
  apply clarsimp
  apply (simp split: if_split_asm;
         clarsimp simp: isMDBParentOf_def isCap_simps split: if_split_asm cong: if_cong)
  done

lemma m_parent_of_next:
  "\<lbrakk> m \<turnstile> p parentOf mdbNext s_node; m \<turnstile> p parentOf slot; p \<noteq> slot; p\<noteq>mdbNext s_node \<rbrakk>
  \<Longrightarrow> n \<turnstile> p parentOf mdbNext s_node"
  using slot
  apply (clarsimp simp add: parentOf_def)
  apply (case_tac cte'a, case_tac cte)
  apply clarsimp
  apply (frule_tac p=p in m_cap)
  apply (frule_tac p=p in m_badged)
  apply (drule_tac p=p in m_revokable)
  apply (frule_tac p="mdbNext s_node" in m_cap)
  apply (frule_tac p="mdbNext s_node" in m_badged)
  apply (drule_tac p="mdbNext s_node" in m_revokable)
  apply (frule_tac p="slot" in m_cap)
  apply (frule_tac p="slot" in m_badged)
  apply (drule_tac p="slot" in m_revokable)
  apply (clarsimp simp: isMDBParentOf_def isCap_simps split: if_split_asm cong: if_cong)
  done

lemma parency_n:
  assumes "n \<turnstile> p \<rightarrow> p'"
  shows "m \<turnstile> p \<rightarrow> p' \<and> p \<noteq> slot \<and> p' \<noteq> slot"
using assms
proof induct
  case (direct_parent c')
  moreover
  hence "p \<noteq> slot"
    by (clarsimp simp: n_next_eq)
  moreover
  from direct_parent
  have "c' \<noteq> slot"
    by (clarsimp simp add: n_next_eq split: if_split_asm)
  ultimately
  show ?case
    apply simp
    apply (simp add: n_next_eq split: if_split_asm)
     prefer 2
     apply (erule (1) subtree.direct_parent)
     apply (erule (2) n_parent_of)
    apply clarsimp
    apply (frule n_parent_of, simp, simp)
    apply (rule subtree.trans_parent[OF _ m_slot_next], simp_all)
    apply (rule subtree.direct_parent)
      apply (erule prev_slot_next)
     apply simp
    apply (clarsimp simp: parentOf_def slot)
    apply (case_tac cte'a)
    apply (case_tac ctea)
    apply clarsimp
    apply (frule(2) mdb_chunked2D [OF chunked prev_slot_next m_slot_next])
      apply (clarsimp simp: isMDBParentOf_CTE)
     apply simp
    apply (simp add: slot)
    apply (clarsimp simp add: isMDBParentOf_CTE)
    apply (insert valid_badges)
    apply (simp add: valid_badges_def2)
    apply (drule spec[where x=slot])
    apply (drule spec[where x="mdbNext s_node"])
    apply (simp add: slot m_slot_next)
    apply (insert valid_badges)
    apply (simp add: valid_badges_def2)
    apply (drule spec[where x="mdbPrev s_node"])
    apply (drule spec[where x=slot])
    apply (simp add: slot prev_slot_next)
    apply (case_tac cte, case_tac cte')
    apply (rename_tac cap'' node'')
    apply (clarsimp simp: isMDBParentOf_CTE)
    apply (frule n_cap, drule n_badged)
    apply (frule n_cap, drule n_badged)
    apply clarsimp
    apply (case_tac cap'', simp_all add: isCap_simps)[1]
     apply (clarsimp simp: sameRegionAs_def3 isCap_simps)
    apply (clarsimp simp: sameRegionAs_def3 isCap_simps)
    done
next
  case (trans_parent c c')
  moreover
  hence "p \<noteq> slot"
    by (clarsimp simp: n_next_eq)
  moreover
  from trans_parent
  have "c' \<noteq> slot"
    by (clarsimp simp add: n_next_eq split: if_split_asm)
  ultimately
  show ?case
    apply clarsimp
    apply (simp add: n_next_eq split: if_split_asm)
     prefer 2
     apply (erule (2) subtree.trans_parent)
     apply (erule n_parent_of, simp, simp)
    apply clarsimp
    apply (rule subtree.trans_parent)
       apply (rule subtree.trans_parent, assumption)
         apply (rule prev_slot_next)
         apply clarsimp
        apply clarsimp
       apply (frule n_parent_of, simp, simp)
       apply (clarsimp simp: parentOf_def slot)
       apply (case_tac cte'a)
       apply (rename_tac cap node)
       apply (case_tac ctea)
       apply clarsimp
       apply (subgoal_tac "sameRegionAs cap s_cap")
        prefer 2
        apply (insert chunked)[1]
        apply (simp add: mdb_chunked_def)
        apply (erule_tac x="p" in allE)
        apply (erule_tac x="mdbNext s_node" in allE)
        apply simp
        apply (drule isMDBParent_sameRegion)+
        apply clarsimp
        apply (subgoal_tac "m \<turnstile> p \<leadsto>\<^sup>+ slot")
         prefer 2
         apply (rule trancl_trans)
          apply (erule subtree_mdb_next)
         apply (rule r_into_trancl)
         apply (rule prev_slot_next)
         apply clarsimp
        apply (subgoal_tac "m \<turnstile> p \<leadsto>\<^sup>+ mdbNext s_node")
         prefer 2
         apply (erule trancl_trans)
         apply fastforce
        apply simp
        apply (erule impE)
         apply clarsimp
        apply clarsimp
        apply (thin_tac "s \<longrightarrow> t" for s t)
        apply (simp add: is_chunk_def)
        apply (erule_tac x=slot in allE)
        apply (erule impE, fastforce)
        apply (erule impE, fastforce)
        apply (clarsimp simp: slot)
       apply (clarsimp simp: isMDBParentOf_CTE)
       apply (insert valid_badges, simp add: valid_badges_def2)
       apply (drule spec[where x=slot], drule spec[where x="mdbNext s_node"])
       apply (simp add: slot m_slot_next)
       apply (case_tac cte, case_tac cte')
       apply (rename_tac cap'' node'')
       apply (clarsimp simp: isMDBParentOf_CTE)
       apply (frule n_cap, drule n_badged)
       apply (frule n_cap, drule n_badged)
       apply (clarsimp split: if_split_asm)
        apply (drule subtree_mdb_next)
        apply (drule no_loops_tranclE[OF no_loops])
        apply (erule notE, rule trancl_into_rtrancl)
        apply (rule trancl.intros(2)[OF _ m_slot_next])
        apply (rule trancl.intros(1), rule prev_slot_next)
        apply simp
       apply (case_tac cap'', simp_all add: isCap_simps)[1]
        apply (clarsimp simp: sameRegionAs_def3 isCap_simps)
       apply (clarsimp simp: sameRegionAs_def3 isCap_simps)
      apply (rule m_slot_next)
     apply simp
    apply (erule n_parent_of, simp, simp)
    done
qed

lemma parency_m:
  assumes "m \<turnstile> p \<rightarrow> p'"
  shows "p \<noteq> slot \<longrightarrow> (if p' \<noteq> slot then n \<turnstile> p \<rightarrow> p' else m \<turnstile> p \<rightarrow> mdbNext s_node \<longrightarrow> n \<turnstile> p \<rightarrow> mdbNext s_node)"
using assms
proof induct
  case (direct_parent c)
  thus ?case
    apply clarsimp
    apply (rule conjI)
     apply clarsimp
     apply (rule subtree.direct_parent)
       apply (simp add: n_next_eq)
       apply clarsimp
       apply (subgoal_tac "mdbPrev s_node \<noteq> 0")
        prefer 2
        apply (clarsimp simp: mdb_next_unfold)
       apply (drule prev_slot_next)
       apply (clarsimp simp: mdb_next_unfold)
      apply assumption
     apply (erule m_parent_of, simp, simp)
      apply clarsimp
     apply clarsimp
     apply (drule dlist_next_src_unique)
       apply fastforce
      apply clarsimp
     apply simp
    apply clarsimp
    apply (rule subtree.direct_parent)
      apply (simp add: n_next_eq)
     apply (drule subtree_parent)
     apply (clarsimp simp: parentOf_def)
    apply (drule subtree_parent)
    apply (erule (1) m_parent_of_next)
     apply clarsimp
    apply clarsimp
    done
next
  case (trans_parent c c')
  thus ?case
    apply clarsimp
    apply (rule conjI)
     apply clarsimp
     apply (cases "c=slot")
      apply simp
      apply (erule impE)
       apply (erule subtree.trans_parent)
         apply fastforce
        apply (clarsimp simp: slot mdb_next_unfold)
       apply (clarsimp simp: slot mdb_next_unfold)
      apply (clarsimp simp: slot mdb_next_unfold)
     apply clarsimp
     apply (erule subtree.trans_parent)
       apply (simp add: n_next_eq)
       apply clarsimp
       apply (subgoal_tac "mdbPrev s_node \<noteq> 0")
        prefer 2
        apply (clarsimp simp: mdb_next_unfold)
       apply (drule prev_slot_next)
       apply (clarsimp simp: mdb_next_unfold)
      apply assumption
     apply (erule m_parent_of, simp, simp)
      apply clarsimp
      apply (drule subtree_mdb_next)
      apply (drule trancl_trans)
       apply (erule r_into_trancl)
      apply simp
     apply clarsimp
     apply (drule dlist_next_src_unique)
       apply fastforce
      apply clarsimp
     apply simp
    apply clarsimp
    apply (erule subtree.trans_parent)
      apply (simp add: n_next_eq)
     apply clarsimp
    apply (rule m_parent_of_next, erule subtree_parent, assumption, assumption)
    apply clarsimp
    done
qed

lemma parency:
  "n \<turnstile> p \<rightarrow> p' = (p \<noteq> slot \<and> p' \<noteq> slot \<and> m \<turnstile> p \<rightarrow> p')"
  by (auto dest!: parency_n parency_m)

lemma descendants:
  "descendants_of' p n =
  (if p = slot then {} else descendants_of' p m - {slot})"
  by (auto simp add: parency descendants_of'_def)

lemma n_tranclD:
  "n \<turnstile> p \<leadsto>\<^sup>+ p' \<Longrightarrow> m \<turnstile> p \<leadsto>\<^sup>+ p' \<and> p' \<noteq> slot"
  apply (erule trancl_induct)
   apply (clarsimp simp add: n_next_eq split: if_split_asm)
     apply (rule mdb_chain_0D)
      apply (rule chain)
     apply (clarsimp simp: slot)
    apply (blast intro: trancl_trans prev_slot_next)
   apply fastforce
  apply (clarsimp simp: n_next_eq split: if_split_asm)
   apply (erule trancl_trans)
   apply (blast intro: trancl_trans prev_slot_next)
  apply (fastforce intro: trancl_trans)
  done

lemma m_tranclD:
  "m \<turnstile> p \<leadsto>\<^sup>+ p' \<Longrightarrow>
  if p = slot then n \<turnstile> mdbNext s_node \<leadsto>\<^sup>* p'
  else if p' = slot then n \<turnstile> p \<leadsto>\<^sup>+ mdbNext s_node
  else n \<turnstile> p \<leadsto>\<^sup>+ p'"
  using no_0_n
  apply -
  apply (erule trancl_induct)
   apply clarsimp
   apply (rule conjI)
    apply clarsimp
    apply (rule r_into_trancl)
    apply (clarsimp simp: n_next_eq)
   apply clarsimp
   apply (rule conjI)
    apply (insert m_slot_next)[1]
    apply (clarsimp simp: mdb_next_unfold)
   apply clarsimp
   apply (rule r_into_trancl)
   apply (clarsimp simp: n_next_eq)
   apply (rule context_conjI)
    apply (clarsimp simp: mdb_next_unfold)
   apply (drule prev_slot_next)
   apply (clarsimp simp: mdb_next_unfold)
  apply clarsimp
  apply (rule conjI)
   apply clarsimp
   apply (rule conjI)
    apply clarsimp
    apply (drule prev_slot_next)
    apply (drule trancl_trans, erule r_into_trancl)
    apply simp
   apply clarsimp
   apply (erule trancl_trans)
   apply (rule r_into_trancl)
   apply (simp add: n_next_eq)
  apply clarsimp
  apply (rule conjI)
   apply clarsimp
   apply (erule rtrancl_trans)
   apply (rule r_into_rtrancl)
   apply (simp add: n_next_eq)
   apply (rule conjI)
    apply clarsimp
    apply (rule context_conjI)
     apply (clarsimp simp: mdb_next_unfold)
    apply (drule prev_slot_next)
    apply (clarsimp simp: mdb_next_unfold)
   apply clarsimp
  apply clarsimp
  apply (simp split: if_split_asm)
   apply (clarsimp simp: mdb_next_unfold slot)
  apply (erule trancl_trans)
  apply (rule r_into_trancl)
  apply (clarsimp simp add: n_next_eq)
  apply (rule context_conjI)
   apply (clarsimp simp: mdb_next_unfold)
  apply (drule prev_slot_next)
  apply (clarsimp simp: mdb_next_unfold)
  done

lemma n_trancl_eq:
  "n \<turnstile> p \<leadsto>\<^sup>+ p' = (m \<turnstile> p \<leadsto>\<^sup>+ p' \<and> (p = slot \<longrightarrow> p' = 0) \<and> p' \<noteq> slot)"
  using no_0_n
  apply -
  apply (rule iffI)
   apply (frule n_tranclD)
   apply clarsimp
   apply (drule tranclD)
   apply (clarsimp simp: n_next_eq)
   apply (simp add: rtrancl_eq_or_trancl)
  apply clarsimp
  apply (drule m_tranclD)
  apply (simp split: if_split_asm)
  apply (rule r_into_trancl)
  apply (simp add: n_next_eq)
  done

lemma n_rtrancl_eq:
  "n \<turnstile> p \<leadsto>\<^sup>* p' =
  (m \<turnstile> p \<leadsto>\<^sup>* p' \<and>
   (p = slot \<longrightarrow> p' = 0 \<or> p' = slot) \<and>
   (p' = slot \<longrightarrow> p = slot))"
  by (auto simp: rtrancl_eq_or_trancl n_trancl_eq)

lemma mdb_chain_0_n:
  "mdb_chain_0 n"
  using chain
  apply (clarsimp simp: mdb_chain_0_def)
  apply (drule bspec)
   apply (fastforce simp: n_def modify_map_if split: if_split_asm)
  apply (simp add: n_trancl_eq)
  done

lemma mdb_chunked_n:
  "mdb_chunked n"
  using chunked
  apply (clarsimp simp: mdb_chunked_def)
  apply (drule n_cap)+
  apply (clarsimp split: if_split_asm)
  apply (case_tac "p=slot", clarsimp)
  apply clarsimp
  apply (erule_tac x=p in allE)
  apply (erule_tac x=p' in allE)
  apply (clarsimp simp: is_chunk_def)
  apply (simp add: n_trancl_eq n_rtrancl_eq)
  apply (rule conjI)
   apply clarsimp
   apply (erule_tac x=p'' in allE)
   apply clarsimp
   apply (drule_tac p=p'' in m_cap)
   apply clarsimp
  apply clarsimp
  apply (erule_tac x=p'' in allE)
  apply clarsimp
  apply (drule_tac p=p'' in m_cap)
  apply clarsimp
  done

lemma untyped_mdb_n:
  "untyped_mdb' n"
  using untyped_mdb
  apply (simp add: untyped_mdb'_def descendants_of'_def parency)
  apply clarsimp
  apply (drule n_cap)+
  apply (clarsimp split: if_split_asm)
  apply (case_tac "p=slot", simp)
  apply clarsimp
  done

lemma untyped_inc_n:
  "untyped_inc' n"
  using untyped_inc
  apply (simp add: untyped_inc'_def descendants_of'_def parency)
  apply clarsimp
  apply (drule n_cap)+
  apply (clarsimp split: if_split_asm)
  apply (case_tac "p=slot", simp)
  apply clarsimp
  apply (erule_tac x=p in allE)
  apply (erule_tac x=p' in allE)
  apply simp
  done

lemmas vn_prev [dest!] = valid_nullcaps_prev [OF _ slot no_0 dlist nullcaps]
lemmas vn_next [dest!] = valid_nullcaps_next [OF _ slot no_0 dlist nullcaps]

lemma nullcaps_n: "valid_nullcaps n"
proof -
  from valid have "valid_nullcaps m" ..
  thus ?thesis
    apply (clarsimp simp: valid_nullcaps_def nullMDBNode_def nullPointer_def)
    apply (frule n_cap)
    apply (frule n_next)
    apply (frule n_badged)
    apply (frule n_revokable)
    apply (drule n_prev)
    apply (case_tac n)
    apply (insert slot)
    apply (fastforce split: if_split_asm)
    done
qed

lemma ut_rev_n: "ut_revocable' n"
  apply(insert valid)
  apply(clarsimp simp: ut_revocable'_def)
  apply(frule n_cap)
  apply(drule n_revokable)
  apply(clarsimp simp: isCap_simps split: if_split_asm)
  apply(simp add: valid_mdb_ctes_def ut_revocable'_def)
  done

lemma class_links_n: "class_links n"
  using valid slot
  apply (clarsimp simp: valid_mdb_ctes_def class_links_def)
  apply (case_tac cte, case_tac cte')
  apply (drule n_nextD)
  apply (clarsimp simp: split: if_split_asm)
    apply (simp add: no_0_n)
   apply (drule n_cap)+
   apply clarsimp
   apply (frule spec[where x=slot],
          drule spec[where x="mdbNext s_node"],
          simp, simp add: m_slot_next)
   apply (drule spec[where x="mdbPrev s_node"],
          drule spec[where x=slot], simp)
  apply (drule n_cap)+
  apply clarsimp
  apply (fastforce split: if_split_asm)
  done

lemma distinct_zombies_m: "distinct_zombies m"
  using valid by (simp add: valid_mdb_ctes_def)

lemma distinct_zombies_n[simp]:
  "distinct_zombies n"
  using distinct_zombies_m
  apply (simp add: n_def distinct_zombies_nonCTE_modify_map)
  apply (subst modify_map_apply[where p=slot])
   apply (simp add: modify_map_def slot)
  apply simp
  apply (rule distinct_zombies_sameMasterE)
    apply (simp add: distinct_zombies_nonCTE_modify_map)
   apply (simp add: modify_map_def slot)
  apply simp
  done

lemma irq_control_n [simp]: "irq_control n"
  using slot
  apply (clarsimp simp: irq_control_def)
  apply (frule n_revokable)
  apply (drule n_cap)
  apply (clarsimp split: if_split_asm)
  apply (frule irq_revocable, rule irq_control)
  apply clarsimp
  apply (drule n_cap)
  apply (clarsimp simp: if_split_asm)
  apply (erule (1) irq_controlD, rule irq_control)
  done

lemma vmdb_n: "valid_mdb_ctes n"
  by (simp add: valid_mdb_ctes_def valid_dlist_n
                no_0_n mdb_chain_0_n valid_badges_n
                caps_contained_n mdb_chunked_n
                untyped_mdb_n untyped_inc_n
                nullcaps_n ut_rev_n class_links_n)

end

context begin interpretation Arch .
crunch postCapDeletion, clearUntypedFreeIndex
  for ctes_of[wp]: "\<lambda>s. P (ctes_of s)"

lemma emptySlot_mdb [wp]:
  "\<lbrace>valid_mdb'\<rbrace>
  emptySlot sl opt
  \<lbrace>\<lambda>_. valid_mdb'\<rbrace>"
  unfolding emptySlot_def
  apply (simp only: case_Null_If valid_mdb'_def)
  apply (wp updateCap_ctes_of_wp getCTE_wp'
            opt_return_pres_lift | simp add: cte_wp_at_ctes_of)+
  apply (clarsimp)
  apply (case_tac cte)
  apply (rename_tac cap node)
  apply (simp)
  apply (subgoal_tac "mdb_empty (ctes_of s) sl cap node")
   prefer 2
   apply (rule mdb_empty.intro)
   apply (rule mdb_ptr.intro)
    apply (rule vmdb.intro)
    apply (simp add: valid_mdb_ctes_def)
   apply (rule mdb_ptr_axioms.intro)
   apply (simp add: cte_wp_at_ctes_of)
  apply (rule conjI, clarsimp simp: valid_mdb_ctes_def)
  apply (erule mdb_empty.vmdb_n[unfolded const_def])
  done
end

lemma if_live_then_nonz_cap'_def2:
  "if_live_then_nonz_cap' =
   (\<lambda>s. \<forall>ptr. ko_wp_at' live' ptr s \<longrightarrow>
              (\<exists>p zr. (option_map zobj_refs' o cteCaps_of s) p = Some zr \<and> ptr \<in> zr))"
  by (fastforce simp: if_live_then_nonz_cap'_def ex_nonz_cap_to'_def cte_wp_at_ctes_of
                      cteCaps_of_def)

lemma updateMDB_ko_wp_at_live[wp]:
  "\<lbrace>\<lambda>s. P (ko_wp_at' live' p' s)\<rbrace>
      updateMDB p m
   \<lbrace>\<lambda>rv s. P (ko_wp_at' live' p' s)\<rbrace>"
  unfolding updateMDB_def Let_def
  apply (rule hoare_pre, wp)
  apply simp
  done

lemma updateCap_ko_wp_at_live[wp]:
  "\<lbrace>\<lambda>s. P (ko_wp_at' live' p' s)\<rbrace>
      updateCap p cap
   \<lbrace>\<lambda>rv s. P (ko_wp_at' live' p' s)\<rbrace>"
  unfolding updateCap_def
  by wp

fun threadCapRefs :: "capability \<Rightarrow> machine_word set" where
    "threadCapRefs (ThreadCap r) = {r}"
  | "threadCapRefs _             = {}"

definition
  "isFinal cap p m \<equiv>
  \<not>isUntypedCap cap \<and>
  (\<forall>p' c. m p' = Some c \<longrightarrow>
          p \<noteq> p' \<longrightarrow> \<not>isUntypedCap c \<longrightarrow>
          \<not> sameObjectAs cap c)"

lemma not_FinalE:
  "\<lbrakk> \<not> isFinal cap sl cps; isUntypedCap cap \<Longrightarrow> P;
     \<And>p c. \<lbrakk> cps p = Some c; p \<noteq> sl; \<not> isUntypedCap c; sameObjectAs cap c \<rbrakk> \<Longrightarrow> P
    \<rbrakk> \<Longrightarrow> P"
  by (fastforce simp: isFinal_def)

definition
 "removeable' sl \<equiv> \<lambda>s cap.
    (\<exists>p. p \<noteq> sl \<and> cte_wp_at' (\<lambda>cte. capMasterCap (cteCap cte) = capMasterCap cap) p s)
    \<or> ((\<forall>p \<in> cte_refs' cap (irq_node' s). p \<noteq> sl \<longrightarrow> cte_wp_at' (\<lambda>cte. cteCap cte = NullCap) p s)
         \<and> (\<forall>p \<in> zobj_refs' cap. ko_wp_at' (Not \<circ> live') p s))"

lemma not_Final_removeable:
  "\<not> isFinal cap sl (cteCaps_of s)
    \<Longrightarrow> removeable' sl s cap"
  apply (erule not_FinalE)
   apply (clarsimp simp: removeable'_def isCap_simps)
  apply (clarsimp simp: cteCaps_of_def sameObjectAs_def2 removeable'_def
                        cte_wp_at_ctes_of)
  apply fastforce
  done

context begin interpretation Arch .
crunch postCapDeletion
  for ko_wp_at'[wp]: "\<lambda>s. P (ko_wp_at' P' p s)"
crunch postCapDeletion
  for cteCaps_of[wp]: "\<lambda>s. P (cteCaps_of s)"
  (simp: cteCaps_of_def o_def)
end

crunch clearUntypedFreeIndex
  for ko_at_live[wp]: "\<lambda>s. P (ko_wp_at' live' ptr s)"

lemma clearUntypedFreeIndex_cteCaps_of[wp]:
  "\<lbrace>\<lambda>s. P (cteCaps_of s)\<rbrace>
       clearUntypedFreeIndex sl \<lbrace>\<lambda>y s. P (cteCaps_of s)\<rbrace>"
  by (simp add: cteCaps_of_def, wp)

lemma emptySlot_iflive'[wp]:
  "\<lbrace>\<lambda>s. if_live_then_nonz_cap' s \<and> cte_wp_at' (\<lambda>cte. removeable' sl s (cteCap cte)) sl s\<rbrace>
     emptySlot sl opt
   \<lbrace>\<lambda>rv. if_live_then_nonz_cap'\<rbrace>"
  apply (simp add: emptySlot_def case_Null_If if_live_then_nonz_cap'_def2
              del: comp_apply)
  apply (rule hoare_pre)
   apply (wp hoare_vcg_all_lift hoare_vcg_disj_lift
             getCTE_wp opt_return_pres_lift
             clearUntypedFreeIndex_ctes_of
             clearUntypedFreeIndex_cteCaps_of
             hoare_vcg_ex_lift
             | wp (once) hoare_vcg_imp_lift
             | simp add: cte_wp_at_ctes_of del: comp_apply)+
  apply (clarsimp simp: modify_map_same imp_conjR[symmetric])
  apply (drule spec, drule(1) mp)
  apply (clarsimp simp: cte_wp_at_ctes_of modify_map_def split: if_split_asm)
  apply (case_tac "p \<noteq> sl")
   apply blast
  apply (simp add: removeable'_def cteCaps_of_def)
  apply (erule disjE)
   apply (clarsimp simp: cte_wp_at_ctes_of modify_map_def
                  dest!: capMaster_same_refs)
   apply fastforce
  apply clarsimp
  apply (drule(1) bspec)
  apply (clarsimp simp: ko_wp_at'_def)
  done

lemma setIRQState_irq_node'[wp]:
  "\<lbrace>\<lambda>s. P (irq_node' s)\<rbrace> setIRQState state irq \<lbrace>\<lambda>_ s. P (irq_node' s)\<rbrace>"
  apply (simp add: setIRQState_def setInterruptState_def getInterruptState_def)
  apply wp
  apply simp
  done

context begin interpretation Arch .
crunch emptySlot
  for irq_node'[wp]: "\<lambda>s. P (irq_node' s)"
end

lemma emptySlot_ifunsafe'[wp]:
  "\<lbrace>\<lambda>s. if_unsafe_then_cap' s \<and> cte_wp_at' (\<lambda>cte. removeable' sl s (cteCap cte)) sl s\<rbrace>
     emptySlot sl opt
   \<lbrace>\<lambda>rv. if_unsafe_then_cap'\<rbrace>"
  apply (simp add: ifunsafe'_def3)
  apply (rule hoare_pre, rule hoare_use_eq_irq_node'[OF emptySlot_irq_node'])
   apply (simp add: emptySlot_def case_Null_If)
   apply (wp opt_return_pres_lift | simp add: o_def)+
   apply (wp getCTE_cteCap_wp clearUntypedFreeIndex_cteCaps_of)+
  apply (clarsimp simp: tree_cte_cteCap_eq[unfolded o_def]
                        modify_map_same
                        modify_map_comp[symmetric]
                 split: option.split_asm if_split_asm
                 dest!: modify_map_K_D)
  apply (clarsimp simp: modify_map_def)
  apply (drule_tac x=cref in spec, clarsimp)
  apply (case_tac "cref' \<noteq> sl")
   apply (rule_tac x=cref' in exI)
   apply (clarsimp simp: modify_map_def)
  apply (simp add: removeable'_def)
  apply (erule disjE)
   apply (clarsimp simp: modify_map_def)
   apply (subst(asm) tree_cte_cteCap_eq[unfolded o_def])
   apply (clarsimp split: option.split_asm dest!: capMaster_same_refs)
   apply fastforce
  apply clarsimp
  apply (drule(1) bspec)
  apply (clarsimp simp: cte_wp_at_ctes_of cteCaps_of_def)
  done

lemmas ctes_of_valid'[elim] = ctes_of_valid_cap''[where r=cte for cte]

crunch setInterruptState
  for valid_idle'[wp]: "valid_idle'"
  (simp: valid_idle'_def)

context begin interpretation Arch .

crunch emptySlot
 for valid_idle'[wp]: "valid_idle'"

crunch deletedIRQHandler, getSlotCap, clearUntypedFreeIndex, updateMDB, getCTE, updateCap
  for ksArch[wp]: "\<lambda>s. P (ksArchState s)"

crunch emptySlot
 for ksIdle[wp]: "\<lambda>s. P (ksIdleThread s)"
crunch emptySlot
 for gsMaxObjectSize[wp]: "\<lambda>s. P (gsMaxObjectSize s)"

end

lemma emptySlot_cteCaps_of:
  "\<lbrace>\<lambda>s. P ((cteCaps_of s)(p \<mapsto> NullCap))\<rbrace>
     emptySlot p opt
   \<lbrace>\<lambda>rv s. P (cteCaps_of s)\<rbrace>"
  apply (simp add: emptySlot_def case_Null_If)
  apply (wp opt_return_pres_lift getCTE_cteCap_wp
            clearUntypedFreeIndex_cteCaps_of)
  apply (clarsimp simp: cteCaps_of_def cte_wp_at_ctes_of)
  apply (auto elim!: rsubst[where P=P]
               simp: modify_map_def fun_upd_def[symmetric] o_def
                     fun_upd_idem cteCaps_of_def
              split: option.splits)
  done

context begin interpretation Arch .

crunch deletedIRQHandler
  for cteCaps_of[wp]: "\<lambda>s. P (cteCaps_of s)"

lemma deletedIRQHandler_valid_global_refs[wp]:
  "\<lbrace>valid_global_refs'\<rbrace> deletedIRQHandler irq \<lbrace>\<lambda>rv. valid_global_refs'\<rbrace>"
  apply (clarsimp simp: valid_global_refs'_def global_refs'_def)
  apply (rule hoare_pre)
   apply (rule hoare_use_eq_irq_node' [OF deletedIRQHandler_irq_node'])
   apply (rule hoare_use_eq [where f=ksIdleThread, OF deletedIRQHandler_ksIdle])
   apply (rule hoare_use_eq [where f=ksArchState, OF deletedIRQHandler_ksArch])
   apply (rule hoare_use_eq[where f="gsMaxObjectSize"], wp)
   apply (simp add: valid_refs'_cteCaps valid_cap_sizes_cteCaps)
   apply (rule deletedIRQHandler_cteCaps_of)
  apply (clarsimp simp: cte_wp_at_ctes_of)
  apply (clarsimp simp: valid_refs'_cteCaps valid_cap_sizes_cteCaps ball_ran_eq)
  done

lemma clearUntypedFreeIndex_valid_global_refs[wp]:
  "\<lbrace>valid_global_refs'\<rbrace> clearUntypedFreeIndex irq \<lbrace>\<lambda>rv. valid_global_refs'\<rbrace>"
  apply (clarsimp simp: valid_global_refs'_def global_refs'_def)
  apply (rule hoare_pre)
   apply (rule hoare_use_eq_irq_node' [OF clearUntypedFreeIndex_irq_node'])
   apply (rule hoare_use_eq [where f=ksIdleThread, OF clearUntypedFreeIndex_ksIdle])
   apply (rule hoare_use_eq [where f=ksArchState, OF clearUntypedFreeIndex_ksArch])
   apply (rule hoare_use_eq[where f="gsMaxObjectSize"], wp)
   apply (simp add: valid_refs'_cteCaps valid_cap_sizes_cteCaps)
   apply (rule clearUntypedFreeIndex_cteCaps_of)
  apply (clarsimp simp: cte_wp_at_ctes_of)
  apply (clarsimp simp: valid_refs'_cteCaps valid_cap_sizes_cteCaps ball_ran_eq)
  done

crunch global.postCapDeletion
  for valid_global_refs[wp]: "valid_global_refs'"

lemma emptySlot_valid_global_refs[wp]:
  "\<lbrace>valid_global_refs' and cte_at' sl\<rbrace> emptySlot sl opt \<lbrace>\<lambda>rv. valid_global_refs'\<rbrace>"
  apply (clarsimp simp: emptySlot_def)
  apply (wpsimp wp: getCTE_wp hoare_drop_imps hoare_vcg_ex_lift simp: cte_wp_at_ctes_of)
  apply (clarsimp simp: valid_global_refs'_def global_refs'_def)
  apply (frule(1) cte_at_valid_cap_sizes_0)
  apply (clarsimp simp: valid_refs'_cteCaps valid_cap_sizes_cteCaps ball_ran_eq)
  done
end

lemmas doMachineOp_irq_handlers[wp]
    = valid_irq_handlers_lift'' [OF doMachineOp_ctes doMachineOp_ksInterruptState]

lemma deletedIRQHandler_irq_handlers'[wp]:
  "\<lbrace>\<lambda>s. valid_irq_handlers' s \<and> (IRQHandlerCap irq \<notin> ran (cteCaps_of s))\<rbrace>
       deletedIRQHandler irq
   \<lbrace>\<lambda>rv. valid_irq_handlers'\<rbrace>"
  apply (simp add: deletedIRQHandler_def setIRQState_def setInterruptState_def getInterruptState_def)
  apply wp
  apply (clarsimp simp: valid_irq_handlers'_def irq_issued'_def ran_def cteCaps_of_def)
  done

context begin interpretation Arch .

lemma postCapDeletion_irq_handlers'[wp]:
  "\<lbrace>\<lambda>s. valid_irq_handlers' s \<and> (cap \<noteq> NullCap \<longrightarrow> cap \<notin> ran (cteCaps_of s))\<rbrace>
       postCapDeletion cap
   \<lbrace>\<lambda>rv. valid_irq_handlers'\<rbrace>"
  by (wpsimp simp: Retype_H.postCapDeletion_def RISCV64_H.postCapDeletion_def)

definition
  "post_cap_delete_pre' cap sl cs \<equiv> case cap of
     IRQHandlerCap irq \<Rightarrow> irq \<le> maxIRQ \<and> (\<forall>sl'. sl \<noteq> sl' \<longrightarrow> cs sl' \<noteq> Some cap)
   | _ \<Rightarrow> False"

end

crunch clearUntypedFreeIndex
  for ksInterruptState[wp]: "\<lambda>s. P (ksInterruptState s)"

lemma emptySlot_valid_irq_handlers'[wp]:
  "\<lbrace>\<lambda>s. valid_irq_handlers' s
          \<and> (\<forall>sl'. info \<noteq> NullCap \<longrightarrow> sl' \<noteq> sl \<longrightarrow> cteCaps_of s sl' \<noteq> Some info)\<rbrace>
     emptySlot sl info
   \<lbrace>\<lambda>rv. valid_irq_handlers'\<rbrace>"
  apply (simp add: emptySlot_def case_Null_If)
  apply (wp | wpc)+
        apply (unfold valid_irq_handlers'_def irq_issued'_def)
        apply (wp getCTE_cteCap_wp clearUntypedFreeIndex_cteCaps_of
          | wps clearUntypedFreeIndex_ksInterruptState)+
  apply (clarsimp simp: cteCaps_of_def cte_wp_at_ctes_of ran_def modify_map_def
                 split: option.split)
  apply auto
  done

declare setIRQState_irq_states' [wp]

context begin interpretation Arch .
crunch emptySlot
  for irq_states'[wp]: valid_irq_states'

crunch emptySlot
  for no_0_obj'[wp]: no_0_obj'
 (wp: crunch_wps)

end

lemma deletedIRQHandler_irqs_masked'[wp]:
  "\<lbrace>irqs_masked'\<rbrace> deletedIRQHandler irq \<lbrace>\<lambda>_. irqs_masked'\<rbrace>"
  apply (simp add: deletedIRQHandler_def setIRQState_def getInterruptState_def setInterruptState_def)
  apply (wp dmo_maskInterrupt)
  apply (simp add: irqs_masked'_def)
  done

context begin interpretation Arch . (*FIXME: arch-split*)

lemma setObject_cte_irq_masked'[wp]:
  "setObject p (v::cte) \<lbrace>irqs_masked'\<rbrace>"
  unfolding setObject_def
  by (wpsimp simp: irqs_masked'_def Ball_def wp: hoare_vcg_all_lift hoare_vcg_imp_lift' updateObject_cte_inv)

crunch emptySlot
 for irqs_masked'[wp]: "irqs_masked'"

lemma setIRQState_umm:
 "\<lbrace>\<lambda>s. P (underlying_memory (ksMachineState s))\<rbrace>
   setIRQState irqState irq
  \<lbrace>\<lambda>_ s. P (underlying_memory (ksMachineState s))\<rbrace>"
  by (simp add: setIRQState_def maskInterrupt_def
                setInterruptState_def getInterruptState_def
      | wp dmo_lift')+

crunch emptySlot
  for umm[wp]: "\<lambda>s. P (underlying_memory (ksMachineState s))"
  (wp: setIRQState_umm)

lemma emptySlot_vms'[wp]:
  "\<lbrace>valid_machine_state'\<rbrace> emptySlot slot irq \<lbrace>\<lambda>_. valid_machine_state'\<rbrace>"
  by (simp add: valid_machine_state'_def pointerInUserData_def pointerInDeviceData_def)
     (wp hoare_vcg_all_lift hoare_vcg_disj_lift)

crunch emptySlot
  for pspace_domain_valid[wp]: "pspace_domain_valid"
  and ksDomSchedule[wp]: "\<lambda>s. P (ksDomSchedule s)"
  and ksDomScheduleIdx[wp]: "\<lambda>s. P (ksDomScheduleIdx s)"

crunch deletedIRQHandler
 for tcbQueued[wp]: "obj_at' (\<lambda>tcb. P (tcbQueued tcb)) t"

crunch emptySlot
  for tcbDomain[wp]: "obj_at' (\<lambda>tcb. P (tcbDomain tcb)) t"

lemma emptySlot_ct_idle_or_in_cur_domain'[wp]:
  "\<lbrace>ct_idle_or_in_cur_domain'\<rbrace> emptySlot sl opt \<lbrace>\<lambda>_. ct_idle_or_in_cur_domain'\<rbrace>"
  by (wp ct_idle_or_in_cur_domain'_lift2 tcb_in_cur_domain'_lift | simp)+

crunch postCapDeletion
  for gsUntypedZeroRanges[wp]: "\<lambda>s. P (gsUntypedZeroRanges s)"
  (wp: crunch_wps simp: crunch_simps)

lemma untypedZeroRange_modify_map_isUntypedCap:
  "m sl = Some v \<Longrightarrow> \<not> isUntypedCap v \<Longrightarrow> \<not> isUntypedCap (f v)
    \<Longrightarrow> (untypedZeroRange \<circ>\<^sub>m modify_map m sl f) = (untypedZeroRange \<circ>\<^sub>m m)"
  by (simp add: modify_map_def map_comp_def fun_eq_iff untypedZeroRange_def)

lemma emptySlot_untyped_ranges[wp]:
  "\<lbrace>untyped_ranges_zero' and valid_objs' and valid_mdb'\<rbrace>
     emptySlot sl opt \<lbrace>\<lambda>rv. untyped_ranges_zero'\<rbrace>"
  apply (simp add: emptySlot_def case_Null_If)
  apply (rule hoare_pre)
   apply (rule bind_wp)
    apply (rule untyped_ranges_zero_lift)
     apply (wp getCTE_cteCap_wp clearUntypedFreeIndex_cteCaps_of
       | wpc | simp add: clearUntypedFreeIndex_def updateTrackedFreeIndex_def
                         getSlotCap_def
                  split: option.split)+
  apply (clarsimp simp: modify_map_comp[symmetric] modify_map_same)
  apply (case_tac "\<not> isUntypedCap (the (cteCaps_of s sl))")
   apply (case_tac "the (cteCaps_of s sl)",
     simp_all add: untyped_ranges_zero_inv_def
                   untypedZeroRange_modify_map_isUntypedCap isCap_simps)[1]
  apply (clarsimp simp: isCap_simps untypedZeroRange_def modify_map_def)
  apply (strengthen untyped_ranges_zero_fun_upd[mk_strg I E])
  apply simp
  apply (simp add: untypedZeroRange_def isCap_simps)
  done

crunch deletedIRQHandler, updateMDB, updateCap, clearUntypedFreeIndex
  for valid_arch'[wp]: valid_arch_state'
  (wp: valid_arch_state_lift')

crunch global.postCapDeletion
  for valid_arch'[wp]: valid_arch_state'

lemma emptySlot_valid_arch'[wp]:
  "\<lbrace>valid_arch_state' and cte_at' sl\<rbrace> emptySlot sl info \<lbrace>\<lambda>rv. valid_arch_state'\<rbrace>"
  by (wpsimp simp: emptySlot_def cte_wp_at_ctes_of
               wp: getCTE_wp hoare_drop_imps hoare_vcg_ex_lift)

crunch emptySlot
  for replies_of'[wp]: "\<lambda>s. P (replies_of' s)"
  and pspace_bounded'[wp]: pspace_bounded'
  and valid_bitmaps[wp]: valid_bitmaps
  and tcbQueued_opt_pred[wp]: "\<lambda>s. P (tcbQueued |< tcbs_of' s)"
  and valid_sched_pointers[wp]: valid_sched_pointers
  (wp: valid_bitmaps_lift)

lemma emptySlot_invs'[wp]:
  "\<lbrace>\<lambda>s. invs' s \<and> cte_wp_at' (\<lambda>cte. removeable' sl s (cteCap cte)) sl s
            \<and> (info \<noteq> NullCap \<longrightarrow> post_cap_delete_pre' info sl (cteCaps_of s) )\<rbrace>
     emptySlot sl info
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp add: invs'_def valid_pspace'_def valid_dom_schedule'_def)
  apply (rule hoare_pre)
   apply (wp valid_irq_node_lift valid_replies'_lift)
  apply (clarsimp simp: cte_wp_at_ctes_of o_def)
  apply (clarsimp simp: post_cap_delete_pre'_def cteCaps_of_def
                 split: capability.split_asm arch_capability.split_asm)
  by auto

lemma deletedIRQHandler_corres:
  "corres dc \<top> \<top>
    (deleted_irq_handler irq)
    (deletedIRQHandler irq)"
  apply (simp add: deleted_irq_handler_def deletedIRQHandler_def)
  apply (rule setIRQState_corres)
  apply (simp add: irq_state_relation_def)
  done

lemma arch_postCapDeletion_corres:
  "acap_relation cap cap' \<Longrightarrow> corres dc \<top> \<top> (arch_post_cap_deletion cap) (RISCV64_H.postCapDeletion cap')"
  by (clarsimp simp: arch_post_cap_deletion_def RISCV64_H.postCapDeletion_def)

lemma postCapDeletion_corres:
  "cap_relation cap cap' \<Longrightarrow> corres dc \<top> \<top> (post_cap_deletion cap) (postCapDeletion cap')"
  apply (cases cap; clarsimp simp: post_cap_deletion_def Retype_H.postCapDeletion_def)
   apply (corresKsimp corres: deletedIRQHandler_corres)
  by (corresKsimp corres: arch_postCapDeletion_corres)

lemma set_cap_trans_state:
  "((),s') \<in> fst (set_cap c p s) \<Longrightarrow> ((),trans_state f s') \<in> fst (set_cap c p (trans_state f s))"
  apply (cases p)
  apply (clarsimp simp add: set_cap_def in_monad set_object_def get_object_def)
  apply (rename_tac obj s'' obj' kobj; case_tac obj)
      by (auto simp: in_monad set_object_def well_formed_cnode_n_def split: if_split_asm)

lemma clearUntypedFreeIndex_noop_corres:
  "corres dc \<top> (cte_at' (cte_map slot))
    (return ()) (clearUntypedFreeIndex (cte_map slot))"
  apply (simp add: clearUntypedFreeIndex_def)
  apply (rule corres_guard_imp)
    apply (rule corres_bind_return2)
    apply (rule corres_symb_exec_r_conj[where P'="cte_at' (cte_map slot)"])
       apply (rule corres_trivial, simp)
      apply (wp getCTE_wp' | wpc
        | simp add: updateTrackedFreeIndex_def getSlotCap_def)+
     apply (clarsimp simp: state_relation_def)
    apply (rule no_fail_pre)
     apply (wp no_fail_getSlotCap getCTE_wp'
       | wpc | simp add: updateTrackedFreeIndex_def getSlotCap_def)+
  done

lemma clearUntypedFreeIndex_valid_pspace'[wp]:
  "\<lbrace>valid_pspace'\<rbrace> clearUntypedFreeIndex slot \<lbrace>\<lambda>rv. valid_pspace'\<rbrace>"
  apply (simp add: valid_pspace'_def)
  apply (wpsimp wp: valid_replies'_lift valid_mdb'_lift)
  done

lemma emptySlot_corres:
  "cap_relation info info' \<Longrightarrow> corres dc (einvs and cte_at slot) (invs' and cte_at' (cte_map slot))
             (empty_slot slot info) (emptySlot (cte_map slot) info')"
  unfolding emptySlot_def empty_slot_def
  apply (simp add: case_Null_If)
  apply (rule corres_guard_imp)
    apply (rule corres_split_noop_rhs[OF clearUntypedFreeIndex_noop_corres])
     apply (rule_tac R="\<lambda>cap. einvs and cte_wp_at ((=) cap) slot" and
                     R'="\<lambda>cte. valid_pspace' and cte_wp_at' ((=) cte) (cte_map slot)" in
                     corres_split[OF get_cap_corres])
       defer
       apply (wp get_cap_wp getCTE_wp')+
     apply (simp add: cte_wp_at_ctes_of)
     apply (wp hoare_vcg_imp_lift' clearUntypedFreeIndex_valid_pspace')
    apply fastforce
   apply (fastforce simp: cte_wp_at_ctes_of)
  apply simp
  apply (rule conjI, clarsimp)
   defer
  apply clarsimp
  apply (rule conjI, clarsimp)
  apply clarsimp
  apply (simp only: bind_assoc[symmetric])
  apply (rule corres_underlying_split[where r'=dc, OF _ postCapDeletion_corres])
    defer
    apply wpsimp+
  apply (rule corres_no_failI)
   apply (rule no_fail_pre, wp hoare_weak_lift_imp)
   apply (clarsimp simp: cte_wp_at_ctes_of valid_pspace'_def)
   apply (clarsimp simp: valid_mdb'_def valid_mdb_ctes_def)
   apply (rule conjI, clarsimp)
    apply (erule (2) valid_dlistEp)
    apply simp
   apply clarsimp
   apply (erule (2) valid_dlistEn)
   apply simp
  apply (clarsimp simp: in_monad bind_assoc exec_gets)
  apply (subgoal_tac "mdb_empty_abs a")
   prefer 2
   apply (rule mdb_empty_abs.intro)
   apply (rule vmdb_abs.intro)
   apply fastforce
  apply (frule mdb_empty_abs'.intro)
  apply (simp add: mdb_empty_abs'.empty_slot_ext_det_def2 update_cdt_list_def set_cdt_list_def exec_gets set_cdt_def bind_assoc exec_get exec_put set_original_def modify_def del: fun_upd_apply | subst bind_def, simp, simp add: mdb_empty_abs'.empty_slot_ext_det_def2)+
  apply (simp add: put_def)
  apply (simp add: exec_gets exec_get exec_put del: fun_upd_apply | subst bind_def)+
  apply (clarsimp simp: state_relation_def)
  apply (drule updateMDB_the_lot, fastforce, fastforce, fastforce)
   apply (clarsimp simp: invs'_def valid_pspace'_def valid_mdb'_def valid_mdb_ctes_def)
  apply (elim conjE)
  apply (drule (4) updateMDB_the_lot, elim conjE)
  apply clarsimp
  apply (drule_tac s'=s''a and c=cap.NullCap in set_cap_not_quite_corres; (simp (no_asm_simp))?)
      subgoal by fastforce
     subgoal by fastforce
    subgoal by fastforce
   apply (erule cte_wp_at_weakenE, rule TrueI)
  apply clarsimp
  apply (drule updateCap_stuff, elim conjE, erule (1) impE)
  apply clarsimp
  apply (drule updateMDB_the_lot, force, assumption+, simp)
  apply (rule bexI)
   prefer 2
   apply (simp only: trans_state_update[symmetric])
   apply (rule set_cap_trans_state)
   apply (rule set_cap_revokable_update)
   apply (erule set_cap_cdt_update)
  apply clarsimp
  apply (thin_tac "ctes_of t = s" for t s)+
  apply (thin_tac "ksMachineState t = p" for t p)+
  apply (thin_tac "ksCurThread t = p" for t p)+
  apply (thin_tac "ksSchedulerAction t = p" for t p)+
  apply (clarsimp simp: cte_wp_at_ctes_of)
  apply (case_tac rv')
  apply (rename_tac s_cap s_node)
  apply (subgoal_tac "cte_at slot a")
   prefer 2
   apply (fastforce elim: cte_wp_at_weakenE)
  apply (subgoal_tac "mdb_empty (ctes_of b) (cte_map slot) s_cap s_node")
   prefer 2
   apply (rule mdb_empty.intro)
   apply (rule mdb_ptr.intro)
    apply (rule vmdb.intro)
    subgoal by (simp add: invs'_def valid_pspace'_def valid_mdb'_def)
   apply (rule mdb_ptr_axioms.intro)
   subgoal by simp
  apply (clarsimp simp: ghost_relation_typ_at set_cap_a_type_inv)

  apply (rule conjI)
   apply (clarsimp simp: data_at_def ghost_relation_typ_at set_cap_a_type_inv)
  apply (rule conjI)
   prefer 2
   apply (rule conjI)
    apply (clarsimp simp: cdt_list_relation_def)
    apply(frule invs_valid_pspace, frule invs_mdb)
    apply(subgoal_tac "no_mloop (cdt a) \<and> finite_depth (cdt a)")
     prefer 2
     subgoal by(simp add: finite_depth valid_mdb_def)
    apply(subgoal_tac "valid_mdb_ctes (ctes_of b)")
     prefer 2
     subgoal by(simp add: mdb_empty_def mdb_ptr_def vmdb_def)
    apply(clarsimp simp: valid_pspace_def)

    apply(case_tac "cdt a slot")
     apply(simp add: next_slot_eq[OF mdb_empty_abs'.next_slot_no_parent])
     apply(case_tac "next_slot (aa, bb) (cdt_list a) (cdt a)")
      subgoal by (simp)
     apply(clarsimp)
     apply(frule(1) mdb_empty.n_next)
     apply(clarsimp)
     apply(erule_tac x=aa in allE, erule_tac x=bb in allE)
     apply(simp split: if_split_asm)
      apply(drule cte_map_inj_eq)
           apply(drule cte_at_next_slot)
             apply(assumption)+
      apply(simp)
     apply(subgoal_tac "(ab, bc) = slot")
      prefer 2
      apply(drule_tac cte="CTE s_cap s_node" in valid_mdbD2')
        subgoal by (clarsimp simp: valid_mdb_ctes_def no_0_def)
       subgoal by (clarsimp simp: invs'_def valid_pspace'_def)
      apply(clarsimp)
      apply(rule cte_map_inj_eq)
           apply(assumption)
          apply(drule(3) cte_at_next_slot', assumption)
         apply(assumption)+
     apply(simp)
     apply(drule_tac p="(aa, bb)" in no_parent_not_next_slot)
        apply(assumption)+
     apply(clarsimp)

    apply(simp add: next_slot_eq[OF mdb_empty_abs'.next_slot] split del: if_split)
    apply(case_tac "next_slot (aa, bb) (cdt_list a) (cdt a)")
     subgoal by (simp)
    apply(case_tac "(aa, bb) = slot", simp)
    apply(case_tac "next_slot (aa, bb) (cdt_list a) (cdt a) = Some slot")
     apply(simp)
     apply(case_tac "next_slot ac (cdt_list a) (cdt a)", simp)
     apply(simp)
     apply(frule(1) mdb_empty.n_next)
     apply(clarsimp)
     apply(erule_tac x=aa in allE', erule_tac x=bb in allE)
     apply(erule_tac x=ac in allE, erule_tac x=bd in allE)
     apply(clarsimp split: if_split_asm)
      apply(drule(1) no_self_loop_next)
      apply(simp)
     apply(drule_tac cte="CTE cap' node'" in valid_mdbD1')
       apply(fastforce simp: valid_mdb_ctes_def no_0_def)
      subgoal by (simp add: valid_mdb'_def)
     apply(clarsimp)
    apply(simp)
    apply(frule(1) mdb_empty.n_next)
    apply(erule_tac x=aa in allE, erule_tac x=bb in allE)
    apply(clarsimp split: if_split_asm)
     apply(drule(1) no_self_loop_prev)
     apply(clarsimp)
     apply(drule_tac cte="CTE s_cap s_node" in valid_mdbD2')
       apply(clarsimp simp: valid_mdb_ctes_def no_0_def)
      apply clarify
     apply(clarsimp)
     apply(drule cte_map_inj_eq)
          apply(drule(3) cte_at_next_slot')
          apply(assumption)+
     apply(simp)
    apply(erule disjE)
     apply(drule cte_map_inj_eq)
          apply(drule(3) cte_at_next_slot)
          apply(assumption)+
     apply(simp)
    subgoal by (simp)
   apply (simp add: revokable_relation_def)
   apply (clarsimp simp: in_set_cap_cte_at)
   apply (rule conjI)
    apply clarsimp
    apply (drule(1) mdb_empty.n_revokable)
    subgoal by clarsimp
   apply clarsimp
   apply (drule (1) mdb_empty.n_revokable)
   apply (subgoal_tac "null_filter (caps_of_state a) (aa,bb) \<noteq> None")
    prefer 2
    apply (drule set_cap_caps_of_state_monad)
    subgoal by (force simp: null_filter_def)
   apply clarsimp
   apply (subgoal_tac "cte_at (aa, bb) a")
    prefer 2
    apply (drule null_filter_caps_of_stateD, erule cte_wp_cte_at)
   apply (drule (2) cte_map_inj_ps, fastforce)
   subgoal by simp
  apply (clarsimp simp add: cdt_relation_def)
  apply (subst mdb_empty_abs.descendants, assumption)
  apply (subst mdb_empty.descendants, assumption)
  apply clarsimp
  apply (frule_tac p="(aa, bb)" in in_set_cap_cte_at)
  apply clarsimp
  apply (frule (2) cte_map_inj_ps, fastforce)
  apply simp
  apply (case_tac "slot \<in> descendants_of (aa,bb) (cdt a)")
   apply (subst inj_on_image_set_diff)
      apply (rule inj_on_descendants_cte_map)
         apply fastforce
        apply fastforce
       apply fastforce
      apply fastforce
     apply fastforce
    subgoal by simp
   subgoal by simp
  apply simp
  apply (subgoal_tac "cte_map slot \<notin> descendants_of' (cte_map (aa,bb)) (ctes_of b)")
   subgoal by simp
  apply (erule_tac x=aa in allE, erule allE, erule (1) impE)
  apply (drule_tac s="cte_map ` u" for u in sym)
  apply clarsimp
  apply (drule cte_map_inj_eq, assumption)
      apply (erule descendants_of_cte_at, fastforce)
     apply fastforce
    apply fastforce
   apply fastforce
  apply simp
  done



text \<open>Some facts about is_final_cap/isFinalCapability\<close>

lemma isFinalCapability_inv:
  "\<lbrace>P\<rbrace> isFinalCapability cap \<lbrace>\<lambda>_. P\<rbrace>"
  apply (simp add: isFinalCapability_def Let_def
              split del: if_split cong: if_cong)
  apply (rule hoare_pre, wp)
   apply (rule hoare_post_imp[where Q'="\<lambda>s. P"], simp)
   apply wp
  apply simp
  done

definition
  final_matters' :: "capability \<Rightarrow> bool"
where
 "final_matters' cap \<equiv> case cap of
    EndpointCap ref bdg s r g gr \<Rightarrow> True
  | NotificationCap ref bdg s r \<Rightarrow> True
  | ReplyCap ref gr \<Rightarrow> True
  | ThreadCap ref \<Rightarrow> True
  | SchedContextCap ref sz \<Rightarrow> True
  | CNodeCap ref bits gd gs \<Rightarrow> True
  | Zombie ptr zb n \<Rightarrow> True
  | IRQHandlerCap irq \<Rightarrow> True
  | ArchObjectCap acap \<Rightarrow> (case acap of
      FrameCap ref rghts sz d mapdata \<Rightarrow> False
    | ASIDControlCap \<Rightarrow> False
    | _ \<Rightarrow> True)
  | _ \<Rightarrow> False"

lemma final_matters_Master:
  "final_matters' (capMasterCap cap) = final_matters' cap"
  by (simp add: capMasterCap_def split: capability.split arch_capability.split,
      simp add: final_matters'_def)

lemma final_matters_sameRegion_sameObject:
  "final_matters' cap \<Longrightarrow> sameRegionAs cap cap' = sameObjectAs cap cap'"
  apply (rule iffI)
   apply (erule sameRegionAsE)
      apply (simp add: sameObjectAs_def3)
      apply (clarsimp simp: isCap_simps sameObjectAs_sameRegionAs final_matters'_def
        split:capability.splits arch_capability.splits)+
  done

lemma final_matters_sameRegion_sameObject2:
  "\<lbrakk> final_matters' cap'; \<not> isUntypedCap cap; \<not> isIRQHandlerCap cap'; \<not> isArchIOPortCap cap' \<rbrakk>
     \<Longrightarrow> sameRegionAs cap cap' = sameObjectAs cap cap'"
  apply (rule iffI)
   apply (erule sameRegionAsE)
       apply (simp add: sameObjectAs_def3)
       apply (fastforce simp: isCap_simps final_matters'_def)
      apply simp
     apply (clarsimp simp: final_matters'_def isCap_simps)
    apply (clarsimp simp: final_matters'_def isCap_simps)
   apply (clarsimp simp: final_matters'_def isCap_simps)
  apply (erule sameObjectAs_sameRegionAs)
  done

lemma notFinal_prev_or_next:
  "\<lbrakk> \<not> isFinal cap x (cteCaps_of s); mdb_chunked (ctes_of s);
      valid_dlist (ctes_of s); no_0 (ctes_of s);
      ctes_of s x = Some (CTE cap node); final_matters' cap \<rbrakk>
     \<Longrightarrow> (\<exists>cap' node'. ctes_of s (mdbPrev node) = Some (CTE cap' node')
              \<and> sameObjectAs cap cap')
      \<or> (\<exists>cap' node'. ctes_of s (mdbNext node) = Some (CTE cap' node')
              \<and> sameObjectAs cap cap')"
  apply (erule not_FinalE)
   apply (clarsimp simp: isCap_simps final_matters'_def)
  apply (clarsimp simp: mdb_chunked_def cte_wp_at_ctes_of cteCaps_of_def
                   del: disjCI)
  apply (erule_tac x=x in allE, erule_tac x=p in allE)
  apply simp
  apply (case_tac z, simp add: sameObjectAs_sameRegionAs)
  apply (elim conjE disjE, simp_all add: is_chunk_def)
   apply (rule disjI2)
   apply (drule tranclD)
   apply (clarsimp simp: mdb_next_unfold)
   apply (drule spec[where x="mdbNext node"])
   apply simp
   apply (drule mp[where P="ctes_of s \<turnstile> x \<leadsto>\<^sup>+ mdbNext node"])
    apply (rule trancl.intros(1), simp add: mdb_next_unfold)
   apply clarsimp
   apply (drule rtranclD)
   apply (erule disjE, clarsimp+)
   apply (drule tranclD)
   apply (clarsimp simp: mdb_next_unfold final_matters_sameRegion_sameObject)
  apply (rule disjI1)
  apply clarsimp
  apply (drule tranclD2)
  apply clarsimp
  apply (frule vdlist_nextD0)
    apply clarsimp
   apply assumption
  apply (clarsimp simp: mdb_prev_def)
  apply (drule rtranclD)
  apply (erule disjE, clarsimp+)
  apply (drule spec, drule(1) mp)
  apply (drule mp, rule trancl_into_rtrancl, erule trancl.intros(1))
  apply clarsimp
  apply (drule iffD1 [OF final_matters_sameRegion_sameObject, rotated])
   apply (subst final_matters_Master[symmetric])
   apply (subst(asm) final_matters_Master[symmetric])
   apply (clarsimp simp: sameObjectAs_def3)
  apply (clarsimp simp: sameObjectAs_def3)
  done

lemma isFinal:
  "\<lbrace>\<lambda>s. valid_mdb' s \<and> cte_wp_at' ((=) cte) x s
          \<and> final_matters' (cteCap cte)
          \<and> Q (isFinal (cteCap cte) x (cteCaps_of s)) s\<rbrace>
    isFinalCapability cte
   \<lbrace>Q\<rbrace>"
  unfolding isFinalCapability_def
  apply (cases cte)
  apply (rename_tac cap node)
  apply (unfold Let_def)
  apply (simp only: if_False)
  apply (wp getCTE_wp')
  apply (cases "mdbPrev (cteMDBNode cte) = nullPointer")
   apply simp
   apply (clarsimp simp: valid_mdb_ctes_def valid_mdb'_def
                         cte_wp_at_ctes_of)
   apply (rule conjI, clarsimp simp: nullPointer_def)
    apply (erule rsubst[where P="\<lambda>x. Q x s" for s], simp)
    apply (rule classical)
    apply (drule(5) notFinal_prev_or_next)
    apply clarsimp
   apply (clarsimp simp: nullPointer_def)
   apply (erule rsubst[where P="\<lambda>x. Q x s" for s])
   apply (rule sym, rule iffI)
    apply (rule classical)
    apply (drule(5) notFinal_prev_or_next)
    apply clarsimp
   apply clarsimp
   apply (clarsimp simp: cte_wp_at_ctes_of cteCaps_of_def)
   apply (case_tac cte)
   apply clarsimp
   apply (clarsimp simp add: isFinal_def)
   apply (erule_tac x="mdbNext node" in allE)
   apply simp
   apply (erule impE)
    apply (clarsimp simp: valid_mdb'_def valid_mdb_ctes_def)
    apply (drule (1) mdb_chain_0_no_loops)
    apply simp
   apply (clarsimp simp: sameObjectAs_def3 isCap_simps)
  apply simp
  apply (clarsimp simp: cte_wp_at_ctes_of
                        valid_mdb_ctes_def valid_mdb'_def)
  apply (case_tac cte)
  apply clarsimp
  apply (rule conjI)
   apply clarsimp
   apply (erule rsubst[where P="\<lambda>x. Q x s" for s])
   apply clarsimp
   apply (clarsimp simp: isFinal_def cteCaps_of_def)
   apply (erule_tac x="mdbPrev node" in allE)
   apply simp
   apply (erule impE)
    apply clarsimp
    apply (drule (1) mdb_chain_0_no_loops)
    apply (subgoal_tac "ctes_of s (mdbNext node) = Some (CTE cap node)")
     apply clarsimp
    apply (erule (1) valid_dlistEp)
     apply clarsimp
    apply (case_tac cte')
    apply clarsimp
   apply (clarsimp simp add: sameObjectAs_def3 isCap_simps)
  apply clarsimp
  apply (rule conjI)
   apply clarsimp
   apply (erule rsubst[where P="\<lambda>x. Q x s" for s], simp)
   apply (rule classical, drule(5) notFinal_prev_or_next)
   apply (clarsimp simp: sameObjectAs_sym nullPointer_def)
  apply (clarsimp simp: nullPointer_def)
  apply (erule rsubst[where P="\<lambda>x. Q x s" for s])
  apply (rule sym, rule iffI)
   apply (rule classical, drule(5) notFinal_prev_or_next)
   apply (clarsimp simp: sameObjectAs_sym)
   apply auto[1]
  apply (clarsimp simp: isFinal_def cteCaps_of_def)
  apply (case_tac cte)
  apply (erule_tac x="mdbNext node" in allE)
  apply simp
  apply (erule impE)
   apply clarsimp
   apply (drule (1) mdb_chain_0_no_loops)
   apply simp
  apply clarsimp
  apply (clarsimp simp: isCap_simps sameObjectAs_def3)
  done
end

lemma (in vmdb) isFinal_no_subtree:
  "\<lbrakk> m \<turnstile> sl \<rightarrow> p; isFinal cap sl (option_map cteCap o m);
      m sl = Some (CTE cap n); final_matters' cap \<rbrakk> \<Longrightarrow> False"
  apply (erule subtree.induct)
   apply (case_tac "c'=sl", simp)
   apply (clarsimp simp: isFinal_def parentOf_def mdb_next_unfold cteCaps_of_def)
   apply (erule_tac x="mdbNext n" in allE)
   apply simp
   apply (clarsimp simp: isMDBParentOf_CTE final_matters_sameRegion_sameObject)
   apply (clarsimp simp: isCap_simps sameObjectAs_def3)
  apply clarsimp
  done

lemma isFinal_no_descendants:
  "\<lbrakk> isFinal cap sl (cteCaps_of s); ctes_of s sl = Some (CTE cap n);
      valid_mdb' s; final_matters' cap \<rbrakk>
  \<Longrightarrow> descendants_of' sl (ctes_of s) = {}"
  apply (clarsimp simp add: descendants_of'_def cteCaps_of_def)
  apply (erule(3) vmdb.isFinal_no_subtree[rotated])
  apply unfold_locales[1]
  apply (simp add: valid_mdb'_def)
  done

lemma (in vmdb) isFinal_untypedParent:
  assumes x: "m slot = Some cte" "isFinal (cteCap cte) slot (option_map cteCap o m)"
             "final_matters' (cteCap cte) \<and> \<not> isIRQHandlerCap (cteCap cte)"
  shows
  "m \<turnstile> x \<rightarrow> slot \<Longrightarrow>
  (\<exists>cte'. m x = Some cte' \<and> isUntypedCap (cteCap cte') \<and> RetypeDecls_H.sameRegionAs (cteCap cte') (cteCap cte))"
  apply (cases "x=slot", simp)
  apply (insert x)
  apply (frule subtree_mdb_next)
  apply (drule subtree_parent)
  apply (drule tranclD)
  apply clarsimp
  apply (clarsimp simp: mdb_next_unfold parentOf_def isFinal_def)
  apply (case_tac cte')
  apply (rename_tac c' n')
  apply (cases cte)
  apply (rename_tac c n)
  apply simp
  apply (erule_tac x=x in allE)
  apply clarsimp
  apply (drule isMDBParent_sameRegion)
  apply simp
  apply (rule classical, simp)
  apply (simp add: final_matters_sameRegion_sameObject2
                   sameObjectAs_sym)
  done

context begin interpretation Arch . (*FIXME: arch-split*)

lemma no_fail_isFinalCapability [wp]:
  "no_fail (valid_mdb' and cte_wp_at' ((=) cte) p) (isFinalCapability cte)"
  apply (simp add: isFinalCapability_def)
  apply (clarsimp simp: Let_def split del: if_split)
  apply (rule no_fail_pre, wp getCTE_wp')
  apply (clarsimp simp: valid_mdb'_def valid_mdb_ctes_def cte_wp_at_ctes_of nullPointer_def)
  apply (rule conjI)
   apply clarsimp
   apply (erule (2) valid_dlistEp)
   apply simp
  apply clarsimp
  apply (rule conjI)
   apply (erule (2) valid_dlistEn)
   apply simp
  apply clarsimp
  apply (rule valid_dlistEn, assumption+)
  apply (erule (2) valid_dlistEp)
  apply simp
  done

lemma corres_gets_lift:
  assumes inv: "\<And>P. \<lbrace>P\<rbrace> g \<lbrace>\<lambda>_. P\<rbrace>"
  assumes res: "\<lbrace>Q'\<rbrace> g \<lbrace>\<lambda>r s. r = g' s\<rbrace>"
  assumes Q: "\<And>s. Q s \<Longrightarrow> Q' s"
  assumes nf: "no_fail Q g"
  shows "corres r P Q f (gets g') \<Longrightarrow> corres r P Q f g"
  apply (clarsimp simp add: corres_underlying_def simpler_gets_def)
  apply (drule (1) bspec)
  apply (rule conjI)
   apply clarsimp
   apply (rule bexI)
    prefer 2
    apply assumption
   apply simp
   apply (frule in_inv_by_hoareD [OF inv])
   apply simp
   apply (drule use_valid, rule res)
    apply (erule Q)
   apply simp
  apply (insert nf)
  apply (clarsimp simp: no_fail_def)
  done

lemma obj_refs_Master:
  "\<lbrakk> cap_relation cap cap'; P cap \<rbrakk>
      \<Longrightarrow> obj_refs cap =
           (if capClass (capMasterCap cap') = PhysicalClass
                  \<and> \<not> isUntypedCap (capMasterCap cap')
            then {capUntypedPtr (capMasterCap cap')} else {})"
  by (clarsimp simp: isCap_simps
              split: cap_relation_split_asm arch_cap.split_asm)

(* FIXME RT: this should maybe replace is_sc_obj_def in is_obj_defs *)
lemma is_sc_obj_def':
  "is_sc_obj n ko = (\<exists>sc. ko = kernel_object.SchedContext sc n \<and> valid_sched_context_size n)"
  unfolding is_sc_obj_def
  apply (case_tac ko; simp)
  by fastforce

lemma isFinalCapability_corres':
  "final_matters' (cteCap cte) \<Longrightarrow>
   corres (=) (invs and cte_wp_at ((=) cap) ptr)
               (invs' and cte_wp_at' ((=) cte) (cte_map ptr))
       (is_final_cap cap) (isFinalCapability cte)"
  apply (rule corres_gets_lift)
      apply (rule isFinalCapability_inv)
     apply (rule isFinal[where x="cte_map ptr"])
    apply clarsimp
    apply (rule conjI, clarsimp)
    apply (rule refl)
   apply (rule no_fail_pre, wp, fastforce)
  apply (simp add: is_final_cap_def)
  apply (clarsimp simp: cte_wp_at_ctes_of cteCaps_of_def state_relation_def)
  apply (frule (1) pspace_relation_ctes_ofI)
    apply fastforce
   apply fastforce
  apply clarsimp
  apply (rule iffI)
   apply (simp add: is_final_cap'_def2 isFinal_def)
   apply clarsimp
   apply (subgoal_tac "obj_refs cap \<noteq> {} \<or> cap_irqs cap \<noteq> {} \<or> arch_gen_refs cap \<noteq> {}")
    prefer 2
    apply (erule_tac x=a in allE)
    apply (erule_tac x=b in allE)
    apply (clarsimp simp: cte_wp_at_def gen_obj_refs_Int)
   apply (subgoal_tac "ptr = (a,b)")
    prefer 2
    apply (erule_tac x="fst ptr" in allE)
    apply (erule_tac x="snd ptr" in allE)
    apply (clarsimp simp: cte_wp_at_def gen_obj_refs_Int)
   apply clarsimp
   apply (rule context_conjI)
    apply (clarsimp simp: isCap_simps)
    apply (cases cap, auto)[1]
   apply clarsimp
   apply (drule_tac x=p' in pspace_relation_cte_wp_atI, assumption)
    apply fastforce
   apply clarsimp
   apply (erule_tac x=aa in allE)
   apply (erule_tac x=ba in allE)
   apply (clarsimp simp: cte_wp_at_caps_of_state)
   apply (clarsimp simp: sameObjectAs_def3 obj_refs_Master cap_irqs_relation_Master
                         arch_gen_refs_relation_Master gen_obj_refs_Int
                   cong: if_cong
                  split: capability.split_asm)
  apply (clarsimp simp: isFinal_def is_final_cap'_def3)
  apply (rule_tac x="fst ptr" in exI)
  apply (rule_tac x="snd ptr" in exI)
  apply (rule conjI)
   apply (clarsimp simp: cte_wp_at_def final_matters'_def
                         gen_obj_refs_Int
                  split: cap_relation_split_asm arch_cap.split_asm)
  apply clarsimp
  apply (drule_tac p="(a,b)" in cte_wp_at_norm)
  apply clarsimp
  apply (frule_tac slot="(a,b)" in pspace_relation_ctes_ofI, assumption)
    apply fastforce
   apply fastforce
  apply clarsimp
  apply (frule_tac p="(a,b)" in cte_wp_valid_cap, fastforce)
  apply (erule_tac x="cte_map (a,b)" in allE)
  apply simp
  apply (erule impCE, simp, drule cte_map_inj_eq)
        apply (erule cte_wp_at_weakenE, rule TrueI)
       apply (erule cte_wp_at_weakenE, rule TrueI)
      apply fastforce
     apply fastforce
    apply (erule invs_distinct)
   apply simp
  apply (frule_tac p=ptr in cte_wp_valid_cap, fastforce)
  apply (clarsimp simp: cte_wp_at_def gen_obj_refs_Int)
  apply (rule conjI)
   apply (rule classical)
   apply (frule(1) zombies_finalD2[OF _ _ _ invs_zombies],
          simp?, clarsimp, assumption+)
    subgoal by (clarsimp simp: sameObjectAs_def3 isCap_simps valid_cap_def valid_arch_cap_def
                               is_sc_obj_def' valid_arch_cap_ref_def obj_at_def is_obj_defs a_type_def
                               final_matters'_def
                     simp del: is_sc_obj_def
                        split: cap.split_asm arch_cap.split_asm option.split_asm if_split_asm,
                 simp_all add: is_cap_defs)
  apply (rule classical)
  by (clarsimp simp: cap_irqs_def cap_irq_opt_def sameObjectAs_def3 isCap_simps
              split: cap.split_asm)

lemma isFinalCapability_corres:
  "corres (\<lambda>rv rv'. final_matters' (cteCap cte) \<longrightarrow> rv = rv')
          (invs and cte_wp_at ((=) cap) ptr)
          (invs' and cte_wp_at' ((=) cte) (cte_map ptr))
       (is_final_cap cap) (isFinalCapability cte)"
  apply (cases "final_matters' (cteCap cte)")
   apply simp
   apply (erule isFinalCapability_corres')
  apply (subst bind_return[symmetric],
         rule corres_symb_exec_r)
     apply (rule corres_no_failI)
      apply wp
     apply (clarsimp simp: in_monad is_final_cap_def simpler_gets_def)
    apply (wp isFinalCapability_inv)+
  apply fastforce
  done

text \<open>Facts about finalise_cap/finaliseCap and
        cap_delete_one/cteDelete in no particular order\<close>


definition
  finaliseCapTrue_standin_simple_def:
  "finaliseCapTrue_standin cap fin \<equiv> finaliseCap cap fin True"

lemmas finaliseCapTrue_standin_def
    = finaliseCapTrue_standin_simple_def
        [unfolded finaliseCap_def, simplified]

lemmas cteDeleteOne_def'
    = eq_reflection [OF cteDeleteOne_def]
lemmas cteDeleteOne_def
    = cteDeleteOne_def'[folded finaliseCapTrue_standin_simple_def]

crunch cteDeleteOne, suspend, prepareThreadDelete
  for typ_at'[wp]: "\<lambda>s. P (typ_at' T p s)"
  and sc_at'_n[wp]: "\<lambda>s. P (sc_at'_n n p s)"
  (wp: crunch_wps  hoare_vcg_if_lift2 hoare_vcg_all_lift
   simp: crunch_simps unless_def o_def)

end

global_interpretation cancelIPC: typ_at_all_props' "cancelIPC x" by typ_at_props'
global_interpretation cancelAllIPC: typ_at_all_props' "cancelAllIPC x" by typ_at_props'
global_interpretation cancelAllSignals: typ_at_all_props' "cancelAllSignals x" by typ_at_props'
global_interpretation suspend: typ_at_all_props' "suspend x" by typ_at_props'

definition
  cap_has_cleanup' :: "capability \<Rightarrow> bool"
where
  "cap_has_cleanup' cap \<equiv> case cap of
     IRQHandlerCap _ \<Rightarrow> True
   | ArchObjectCap acap \<Rightarrow> False
   | _ \<Rightarrow> False"

lemmas cap_has_cleanup'_simps[simp] = cap_has_cleanup'_def[split_simps capability.split]

lemma finaliseCap_cases[wp]:
  "\<lbrace>\<top>\<rbrace>
     finaliseCap cap final flag
   \<lbrace>\<lambda>rv s. fst rv = NullCap \<and> (snd rv \<noteq> NullCap \<longrightarrow> final \<and> cap_has_cleanup' cap \<and> snd rv = cap)
     \<or>
       isZombie (fst rv) \<and> final \<and> \<not> flag \<and> snd rv = NullCap
        \<and> capUntypedPtr (fst rv) = capUntypedPtr cap
        \<and> (isThreadCap cap \<or> isCNodeCap cap \<or> isZombie cap)\<rbrace>"
  apply (simp add: finaliseCap_def RISCV64_H.finaliseCap_def Let_def
                   getThreadCSpaceRoot
             cong: if_cong split del: if_split)
  apply (rule hoare_pre)
   apply ((wp | simp add: isCap_simps split del: if_split
              | wpc
              | simp only: valid_NullCap fst_conv snd_conv)+)[1]
  apply (simp only: simp_thms fst_conv snd_conv option.simps if_cancel
                    o_def)
  apply (intro allI impI conjI TrueI)
  apply (auto simp add: isCap_simps cap_has_cleanup'_def)
  done

context begin interpretation Arch . (*FIXME: arch-split*)

crunch finaliseCap
  for aligned'[wp]: pspace_aligned'
  and distinct'[wp]: pspace_distinct'
  and bounded'[wp]: pspace_bounded'
  and pspace_canonical'[wp]: pspace_canonical'
  and typ_at'[wp]: "\<lambda>s. P (typ_at' T p s)"
  and sc_at'_n[wp]: "\<lambda>s. P (sc_at'_n n p s)"
  and it'[wp]: "\<lambda>s. P (ksIdleThread s)"
  and irq_node'[wp]: "\<lambda>s. P (irq_node' s)"
  (wp: crunch_wps setObject_asidpool.getObject_inv hoare_vcg_all_lift simp: crunch_simps)

end

global_interpretation unbindFromSC: typ_at_all_props' "unbindFromSC t"
  by typ_at_props'

global_interpretation finaliseCap: typ_at_all_props' "finaliseCap cap final x"
  by typ_at_props'

lemma ntfn_q_refs_of'_mult:
  "ntfn_q_refs_of' ntfn = (case ntfn of Structures_H.WaitingNtfn q \<Rightarrow> set q | _ \<Rightarrow> {}) \<times> {NTFNSignal}"
  by (cases ntfn, simp_all)

lemma tcb_st_not_Bound:
  "(p, NTFNBound) \<notin> tcb_st_refs_of' ts"
  "(p, TCBBound) \<notin> tcb_st_refs_of' ts"
  by (auto simp: tcb_st_refs_of'_def split: Structures_H.thread_state.split)

lemma get_refs_NTFNSchedContext_not_Bound:
  "(tcb, NTFNBound) \<notin> get_refs NTFNSchedContext (ntfnSc ntfn)"
  by (clarsimp simp: get_refs_def split: option.splits)

crunch setBoundNotification
  for valid_bitmaps[wp]: valid_bitmaps
  and tcbSchedNexts_of[wp]: "\<lambda>s. P (tcbSchedNexts_of s)"
  and tcbSchedPrevs_of[wp]: "\<lambda>s. P (tcbSchedPrevs_of s)"
  and tcbQueued[wp]: "\<lambda>s. P (tcbQueued |< tcbs_of' s)"
  and valid_sched_pointers[wp]: valid_sched_pointers
  (wp: valid_bitmaps_lift)

lemma unbindNotification_invs[wp]:
  "unbindNotification tcb \<lbrace>invs'\<rbrace>"
  apply (simp add: unbindNotification_def invs'_def valid_dom_schedule'_def)
  apply (rule bind_wp[OF _ gbn_sp'])
  apply (case_tac ntfnPtr, clarsimp, wp, clarsimp)
  apply clarsimp
  apply (rule bind_wp[OF _ get_ntfn_sp'])
  apply (rule hoare_pre)
   apply (wp sbn'_valid_pspace'_inv sbn_sch_act' valid_irq_node_lift
             irqs_masked_lift setBoundNotification_ct_not_inQ
             sym_heap_sched_pointers_lift
             untyped_ranges_zero_lift | clarsimp simp: cteCaps_of_def o_def)+
  apply (rule conjI)
   apply (frule obj_at_valid_objs', clarsimp+)
   apply (simp add: valid_ntfn'_def valid_obj'_def
             split: ntfn.splits)
  apply (rule conjI)
   apply (clarsimp simp: pred_tcb_at'_def obj_at'_def)
  apply (clarsimp simp: pred_tcb_at' conj_comms)
  apply (erule if_live_then_nonz_capE')
  apply (clarsimp simp: obj_at'_def ko_wp_at'_def live_ntfn'_def)
  done

lemma ntfn_bound_tcb_at':
  "\<lbrakk>sym_refs (state_refs_of' s); valid_objs' s; ko_at' ntfn ntfnptr s;
    ntfnBoundTCB ntfn = Some tcbptr; P (Some ntfnptr)\<rbrakk>
  \<Longrightarrow> bound_tcb_at' P tcbptr s"
  apply (drule_tac x=ntfnptr in sym_refsD[rotated])
   apply (clarsimp simp: obj_at'_def)
   apply (fastforce simp: state_refs_of'_def)
  apply (auto simp: pred_tcb_at'_def obj_at'_def valid_obj'_def valid_ntfn'_def
                    state_refs_of'_def refs_of_rev'
          simp del: refs_of_simps
             split: option.splits if_split_asm)
  done

lemma unbindMaybeNotification_invs[wp]:
  "unbindMaybeNotification ntfnptr \<lbrace>invs'\<rbrace>"
  apply (simp add: unbindMaybeNotification_def invs'_def valid_dom_schedule'_def)
  apply (rule bind_wp[OF _ get_ntfn_sp'])
  apply (wpsimp wp: sbn'_valid_pspace'_inv sbn_sch_act'
                    valid_irq_node_lift irqs_masked_lift setBoundNotification_ct_not_inQ
                    untyped_ranges_zero_lift sym_heap_sched_pointers_lift
              simp: cteCaps_of_def)
  by (auto simp: pred_tcb_at' valid_pspace'_def valid_obj'_def
                 valid_ntfn'_def ko_wp_at'_def live_ntfn'_def o_def
          elim!: obj_atE' if_live_then_nonz_capE'
          split: option.splits ntfn.splits)

lemma setNotification_invs':
  "\<lbrace>invs'
    and (\<lambda>s. live_ntfn' ntfn \<longrightarrow> ex_nonz_cap_to' ntfnPtr s)
    and valid_ntfn' ntfn\<rbrace>
   setNotification ntfnPtr ntfn
   \<lbrace>\<lambda>_. invs'\<rbrace>"
  apply (simp add: invs'_def valid_dom_schedule'_def)
  apply (wpsimp wp: untyped_ranges_zero_lift simp: cteCaps_of_def o_def)
  done

lemma schedContextUnbindNtfn_valid_objs'[wp]:
  "schedContextUnbindNtfn scPtr \<lbrace>valid_objs'\<rbrace>"
  unfolding schedContextUnbindNtfn_def
  apply (wpsimp wp: getNotification_wp hoare_vcg_all_lift hoare_vcg_imp_lift')
  apply normalise_obj_at'
  apply (rename_tac ntfnPtr ntfn sc)
  apply (frule_tac k=ntfn in ko_at_valid_objs'; clarsimp)
  apply (frule_tac k=sc in ko_at_valid_objs'; clarsimp simp: valid_obj'_def)
  by (auto simp: valid_sched_context'_def valid_sched_context_size'_def objBits_simps'
                 valid_ntfn'_def refillSize_def
          split: ntfn.splits)

lemma schedContextUnbindNtfn_invs'[wp]:
  "schedContextUnbindNtfn scPtr \<lbrace>invs'\<rbrace>"
  unfolding invs'_def valid_pspace'_def valid_dom_schedule'_def
  apply wpsimp \<comment> \<open>this handles valid_objs' separately\<close>
   unfolding schedContextUnbindNtfn_def
   apply (wpsimp wp: getNotification_wp hoare_vcg_all_lift hoare_vcg_imp_lift'
                     typ_at_lifts valid_ntfn_lift')
  by (auto simp: ko_wp_at'_def obj_at'_def live_sc'_def live_ntfn'_def o_def
          elim!: if_live_then_nonz_capE')

crunch schedContextMaybeUnbindNtfn
  for invs'[wp]: invs'
  (simp: crunch_simps wp: crunch_wps ignore: setReply)

lemma replyUnlink_invs'[wp]:
  "\<lbrace>invs' and (\<lambda>s. replyTCBs_of s replyPtr = Some tcbPtr \<longrightarrow> \<not> is_reply_linked replyPtr s)\<rbrace>
   replyUnlink replyPtr tcbPtr
   \<lbrace>\<lambda>_. invs'\<rbrace>"
  unfolding invs'_def valid_dom_schedule'_def valid_pspace'_def
  by wpsimp

crunch replyRemove
  for if_unsafe_then_cap'[wp]: if_unsafe_then_cap'
  and valid_global_refs'[wp]: valid_global_refs'
  and valid_arch_state'[wp]: valid_arch_state'
  and valid_irq_node'[wp]: "\<lambda>s. valid_irq_node' (irq_node' s) s"
  and valid_irq_handlers'[wp]: valid_irq_handlers'
  and valid_irq_states'[wp]: valid_irq_states'
  and valid_machine_state'[wp]: valid_machine_state'
  and irqs_masked'[wp]: irqs_masked'
  and ct_idle_or_in_cur_domain'[wp]: ct_idle_or_in_cur_domain'
  and pspace_domain_valid[wp]: pspace_domain_valid
  and ksCurDomain[wp]: "\<lambda>s. P (ksCurDomain s)"
  and untyped_ranges_zero'[wp]: untyped_ranges_zero'
  and cur_tcb'[wp]: cur_tcb'
  and no_0_obj'[wp]: no_0_obj'
  and valid_dom_schedule'[wp]: valid_dom_schedule'
  and pspace_bounded'[wp]: pspace_bounded'
  and pspace_in_kernel_mappings'[wp]: pspace_in_kernel_mappings'
  (simp: crunch_simps wp: crunch_wps)

context begin interpretation Arch . (*FIXME: arch-split*)

crunch replyRemove, handleFaultReply
  for ex_nonz_cap_to'[wp]: "ex_nonz_cap_to' ptr"
  (wp: crunch_wps simp: crunch_simps)

end

global_interpretation replyRemove: typ_at_all_props' "replyRemove replyPtr tcbPtr"
  by typ_at_props'

lemma replyNext_update_valid_objs':
  "\<lbrace>valid_objs' and
      (\<lambda>s. ((\<forall>r. next_opt = Some (Next r) \<longrightarrow> reply_at' r s) \<and>
            (\<forall>sc. next_opt = Some (Head sc) \<longrightarrow> sc_at' sc s)))\<rbrace>
   updateReply replyPtr (replyNext_update (\<lambda>_. next_opt))
   \<lbrace>\<lambda>_. valid_objs'\<rbrace>"
  apply (case_tac next_opt; wpsimp wp: updateReply_valid_objs' simp: valid_reply'_def)
  by (case_tac a; clarsimp)

lemma replyPop_valid_objs'[wp]:
  "\<lbrace>valid_objs' and valid_sched_pointers and sym_heap_sched_pointers
    and pspace_aligned' and pspace_distinct' and pspace_bounded'\<rbrace>
   replyPop replyPtr tcbPtr
   \<lbrace>\<lambda>_. valid_objs'\<rbrace>"
  unfolding replyPop_def
  supply if_split[split del]
  apply (rule bind_wp_fwd_skip, wpsimp)
  apply (wpsimp wp: schedContextDonate_valid_objs' hoare_vcg_if_lift_strong threadGet_const)
                  apply (clarsimp simp: obj_at'_def)
                 apply (wpsimp wp: replyNext_update_valid_objs' hoare_drop_imp hoare_vcg_if_lift2)+
                apply (wpsimp wp: hoare_vcg_all_lift hoare_vcg_imp_lift hoare_vcg_if_lift2 )+
  apply (simp add: isHead_to_head)
  apply (drule_tac k=x in ko_at_valid_objs'; clarsimp simp: valid_obj'_def
                 valid_sched_context'_def valid_sched_context_size'_def objBits_simps refillSize_def)
  apply (drule_tac k=ko in ko_at_valid_objs'; clarsimp simp: valid_obj'_def
                 valid_sched_context'_def valid_sched_context_size'_def objBits_simps refillSize_def)
  apply (clarsimp simp: valid_reply'_def)
  done

lemma replyRemove_valid_objs'[wp]:
  "\<lbrace>valid_objs' and valid_sched_pointers and sym_heap_sched_pointers
    and pspace_aligned' and pspace_distinct' and pspace_bounded'\<rbrace>
   replyRemove replyPtr tcbPtr
   \<lbrace>\<lambda>_. valid_objs'\<rbrace>"
  apply (clarsimp simp: replyRemove_def)
  apply (wpsimp wp: updateReply_valid_objs' hoare_vcg_all_lift hoare_drop_imps
              simp: valid_reply'_def
         | intro conjI impI)+
  done

lemma replyPop_valid_replies'[wp]:
  "\<lbrace>\<lambda>s. valid_replies' s \<and> pspace_aligned' s \<and> pspace_distinct' s
        \<and> sym_refs (list_refs_of_replies' s)\<rbrace>
   replyPop replyPtr tcbPtr
   \<lbrace>\<lambda>_. valid_replies'\<rbrace>"
  unfolding replyPop_def
  supply if_split[split del]
  apply (wpsimp wp: hoare_vcg_imp_lift)
                 apply (wpsimp wp: updateReply_valid_replies'_bound hoare_vcg_imp_lift
                                   hoare_vcg_all_lift hoare_vcg_ex_lift hoare_vcg_if_lift)+
  apply (rename_tac prevReplyPtr)
  apply (drule_tac rptr=prevReplyPtr in valid_replies'D)
   apply (frule reply_sym_heap_Prev_Next)
   apply (frule_tac p=replyPtr in sym_heapD1)
    apply (fastforce simp: opt_map_def obj_at'_def)
   apply clarsimp
  apply (fastforce simp: obj_at'_def elim!: opt_mapE)
  done

lemma replyRemove_valid_replies'[wp]:
  "\<lbrace>\<lambda>s. valid_replies' s \<and> pspace_aligned' s \<and> pspace_distinct' s
        \<and> sym_refs (list_refs_of_replies' s)\<rbrace>
   replyRemove replyPtr tcbPtr
   \<lbrace>\<lambda>_. valid_replies'\<rbrace>"
  unfolding replyRemove_def
  by (wpsimp wp: hoare_vcg_imp_lift')

lemma replyPop_valid_mdb'[wp]:
  "replyPop replyPtr tcbPtr \<lbrace>valid_mdb'\<rbrace>"
  unfolding replyPop_def
  apply (wpsimp wp: schedContextDonate_valid_mdb' hoare_vcg_if_lift_strong threadGet_const)
  apply (clarsimp simp: obj_at'_def)
  by (wpsimp wp: gts_wp')+

lemma replyRemove_valid_mdb'[wp]:
  "replyRemove replyPtr tcbPtr \<lbrace>valid_mdb'\<rbrace>"
  unfolding replyRemove_def
  by (wpsimp wp: gts_wp')+

lemma replyRemove_valid_pspace'[wp]:
  "\<lbrace>\<lambda>s. valid_pspace' s \<and> sym_refs (list_refs_of_replies' s)
        \<and> valid_sched_pointers s \<and> sym_heap_sched_pointers s\<rbrace>
   replyRemove replyPtr tcbPtr
   \<lbrace>\<lambda>_. valid_pspace'\<rbrace>"
  by (wpsimp simp: valid_pspace'_def)

crunch updateReply
  for obj_at'_tcb[wp]: "\<lambda>s. Q (obj_at' (P :: tcb \<Rightarrow> bool) tcbPtr s)"

lemma replyPop_list_refs_of_replies'[wp]:
  "\<lbrace>\<lambda>s. sym_refs (list_refs_of_replies' s) \<and> obj_at' (\<lambda>reply. replyNext reply \<noteq> None) replyPtr s\<rbrace>
   replyPop replyPtr tcbPtr
   \<lbrace>\<lambda>_ s. sym_refs (list_refs_of_replies' s)\<rbrace>"
  unfolding replyPop_def decompose_list_refs_of_replies'
  apply (wpsimp wp: cleanReply_list_refs_of_replies' hoare_vcg_if_lift hoare_vcg_imp_lift' gts_wp'
                    haskell_assert_wp
         split_del: if_split)
  apply (intro conjI impI)
    apply (all \<open>normalise_obj_at'\<close>)
   unfolding decompose_list_refs_of_replies'[symmetric] protected_sym_refs_def[symmetric]
   \<comment>\<open> opt_mapE will sometimes destroy the @{term "(|>)"} inside @{term replyNexts_of}
       and @{term replyPrevs_of}, but we're using those as our local normal form. \<close>
   supply opt_mapE[rule del]
   \<comment>\<open> Our 6 cases correspond to various cases of @{term replyNext} and @{term replyPrev}.
       We use @{thm ks_reply_at'_repliesD} to turn those cases into facts about
       @{term replyNexts_of} and @{term replyPrevs_of}. \<close>
   apply (all \<open>normalise_obj_at'\<close>)
   apply (all \<open>drule(1) ks_reply_at'_repliesD[OF ko_at'_replies_of',
                                                 folded protected_sym_refs_def],
               clarsimp simp: isHead_to_head\<close>)
   \<comment>\<open> Now, for each case we can blow open @{term sym_refs}, which will give us enough new
       @{term "(replyNexts_of, replyPrevs_of)"} facts that we can throw it all at metis. \<close>
   by (clarsimp simp: sym_refs_def split_paired_Ball in_get_refs,
       intro conjI impI allI;
       metis sym_refs_replyNext_replyPrev_sym[folded protected_sym_refs_def] option.inject)+

\<comment> \<open>An almost exact duplicate of replyRemoveTCB_list_refs_of_replies'\<close>
lemma replyRemove_list_refs_of_replies'[wp]:
  "replyRemove replyPtr tcbPtr \<lbrace>\<lambda>s. sym_refs (list_refs_of_replies' s)\<rbrace>"
  unfolding replyRemove_def decompose_list_refs_of_replies'
  supply if_cong[cong]
  apply (wpsimp wp: cleanReply_list_refs_of_replies' hoare_vcg_if_lift hoare_vcg_imp_lift' gts_wp'
                    haskell_assert_wp
                    replyPop_list_refs_of_replies'[simplified decompose_list_refs_of_replies']
              simp: pred_tcb_at'_def
         split_del: if_split)
  unfolding decompose_list_refs_of_replies'[symmetric] protected_sym_refs_def[symmetric]
  \<comment>\<open> opt_mapE will sometimes destroy the @{term "(|>)"} inside @{term replyNexts_of}
      and @{term replyPrevs_of}, but we're using those as our local normal form. \<close>
  supply opt_mapE[rule del]
  apply (intro conjI impI allI)
       \<comment>\<open> Our 6 cases correspond to various cases of @{term replyNext} and @{term replyPrev}.
           We use @{thm ks_reply_at'_repliesD} to turn those cases into facts about
           @{term replyNexts_of} and @{term replyPrevs_of}. \<close>
      apply (all \<open>normalise_obj_at'\<close>)
     apply (all \<open>drule(1) ks_reply_at'_repliesD[OF ko_at'_replies_of',
                                                   folded protected_sym_refs_def]
                 , clarsimp simp: isHead_to_head\<close>)
     \<comment>\<open> Now, for each case we can blow open @{term sym_refs}, which will give us enough new
           @{term "(replyNexts_of, replyPrevs_of)"} facts that we can throw it all at metis. \<close>
     by (clarsimp simp: sym_refs_def split_paired_Ball in_get_refs,
         intro conjI impI allI;
         metis sym_refs_replyNext_replyPrev_sym[folded protected_sym_refs_def] option.inject)+

lemma live'_HeadScPtr:
  "\<lbrakk>replyNext reply = Some reply_next; sym_refs (state_refs_of' s); ko_at' reply replyPtr s;
    isHead (Some reply_next); ko_at' sc (theHeadScPtr (Some reply_next)) s;
    valid_bound_ntfn' (scNtfn sc) s\<rbrakk>
   \<Longrightarrow> ko_wp_at' live' (theHeadScPtr (Some reply_next)) s"
  apply (clarsimp simp: theHeadScPtr_def getHeadScPtr_def isHead_def
                 split: reply_next.splits)
  apply (rename_tac head)
  apply (prop_tac "(head, ReplySchedContext) \<in> state_refs_of' s replyPtr")
   apply (clarsimp simp: state_refs_of'_def get_refs_def2 obj_at'_def)
  apply (prop_tac "(replyPtr, SCReply) \<in> state_refs_of' s head")
   apply (fastforce simp: sym_refs_def)
  apply (clarsimp simp: state_refs_of'_def get_refs_def2 obj_at'_def ko_wp_at'_def
                        live_sc'_def)
  done

lemma replyPop_iflive:
  "\<lbrace>if_live_then_nonz_cap' and valid_objs' and ex_nonz_cap_to' tcbPtr
    and sym_heap_sched_pointers and valid_sched_pointers
    and (\<lambda>s. sym_refs (list_refs_of_replies' s))
    and pspace_aligned' and pspace_distinct' and pspace_bounded'\<rbrace>
   replyPop replyPtr tcbPtr
   \<lbrace>\<lambda>_. if_live_then_nonz_cap'\<rbrace>"
  (is "\<lbrace>?pre\<rbrace> _ \<lbrace>_\<rbrace>")
  unfolding replyPop_def
  apply (wpsimp wp: setSchedContext_iflive' schedContextDonate_if_live_then_nonz_cap'
                    threadGet_inv hoare_vcg_if_lift2
         | wp (once) hoare_drop_imps)+
                 apply (wpsimp wp: updateReply_iflive' updateReply_valid_objs')
                apply (wpsimp wp: updateReply_iflive'_strong updateReply_valid_objs'
                            simp: valid_reply'_def)
               apply (rule_tac Q'="\<lambda>_. ?pre
                                      and ex_nonz_cap_to' scPtr
                                      and (\<lambda>s. prevReplyPtrOpt \<noteq> Nothing
                                               \<longrightarrow> ex_nonz_cap_to' (fromJust prevReplyPtrOpt) s)
                                      and valid_reply' reply"
                            in hoare_post_imp)
                apply (force simp: valid_reply'_def live_reply'_def)
               apply (wpsimp wp: hoare_vcg_imp_lift')
              apply (wpsimp wp: gts_wp')+
  apply (rename_tac reply_next state sched_context)
  apply (frule (1) sc_ko_at_valid_objs_valid_sc')
  apply (frule (1) reply_ko_at_valid_objs_valid_reply')
  apply (clarsimp simp: valid_sched_context'_def comp_def valid_reply'_def sym_refs_asrt_def)
  apply (prop_tac "ex_nonz_cap_to' (theHeadScPtr (Some reply_next)) s")
   apply (fastforce elim: if_live_then_nonz_capE'
                   intro: live'_HeadScPtr)
  apply (clarsimp simp: refillSize_def)
  apply (erule if_live_then_nonz_capE')
  apply (rename_tac replyPrevPtr)
  apply (prop_tac "(replyPrevPtr, ReplyPrev) \<in> list_refs_of_replies' s replyPtr")
   apply (clarsimp simp: list_refs_of_replies'_def list_refs_of_reply'_def obj_at'_def opt_map_def)
  apply (frule sym_refsD, simp)
  by (fastforce simp: ko_wp_at'_def obj_at'_def list_refs_of_replies'_def live_reply'_def
                      opt_map_def list_refs_of_reply'_def)

lemma replyRemove_if_live_then_nonz_cap':
  "\<lbrace>if_live_then_nonz_cap' and valid_objs' and ex_nonz_cap_to' tcbPtr
    and sym_heap_sched_pointers and valid_sched_pointers
    and (\<lambda>s. sym_refs (list_refs_of_replies' s))
    and pspace_aligned' and pspace_distinct' and pspace_bounded'\<rbrace>
   replyRemove replyPtr tcbPtr
   \<lbrace>\<lambda>_. if_live_then_nonz_cap'\<rbrace>"
  apply (clarsimp simp: replyRemove_def)
  apply (rule bind_wp_fwd_skip, wpsimp)
  apply (intro bind_wp[OF _ get_reply_sp']
               bind_wp[OF _ assert_sp]
               bind_wp[OF _ assert_opt_sp]
               bind_wp[OF _ gts_sp'])
  apply (rule hoare_if)
   apply (wpsimp wp: replyPop_iflive)
  apply (clarsimp simp: when_def)
  apply (intro conjI impI; (solves wpsimp)?)
    apply (clarsimp simp: theReplyNextPtr_def)
    apply (rename_tac prev_reply next_reply)
    apply (wpsimp wp: updateReply_iflive'_strong hoare_drop_imps)
    apply (frule_tac rp'=replyPtr and rp=prev_reply in sym_refs_replyNext_replyPrev_sym)
    apply (frule (1) reply_ko_at_valid_objs_valid_reply')
    apply (fastforce elim: if_live_then_nonz_capE'
                     simp: valid_reply'_def ko_wp_at'_def obj_at'_def live_reply'_def opt_map_def)
   apply (wpsimp wp: updateReply_iflive'_strong)
   apply (fastforce simp: live_reply'_def)
  apply (wpsimp wp: updateReply_iflive'_strong)
  apply (fastforce simp: live_reply'_def)
  done

crunch replyRemove
  for valid_bitmaps[wp]: valid_bitmaps
  and sym_heap_sched_pointers[wp]: sym_heap_sched_pointers
  and valid_sched_pointers[wp]: valid_sched_pointers
  (simp: crunch_simps wp: crunch_wps)

lemma replyPop_invs':
  "\<lbrace>invs' and obj_at' (\<lambda>reply. replyNext reply \<noteq> None) replyPtr
          and ex_nonz_cap_to' tcbPtr\<rbrace>
   replyPop replyPtr tcbPtr
   \<lbrace>\<lambda>_. invs'\<rbrace>"
  unfolding invs'_def
  by (wpsimp wp: replyPop_iflive simp: valid_pspace'_def)

lemma replyRemove_invs':
  "\<lbrace>invs' and ex_nonz_cap_to' tcbPtr\<rbrace>
   replyRemove replyPtr tcbPtr
   \<lbrace>\<lambda>_. invs'\<rbrace>"
  unfolding invs'_def
  apply (wpsimp wp: replyRemove_if_live_then_nonz_cap')
  apply fastforce
  done

lemma replyClear_invs'[wp]:
  "replyClear replyPtr tcbPtr \<lbrace>invs'\<rbrace>"
  unfolding replyClear_def
  apply (wpsimp wp: replyRemove_invs' gts_wp')
  apply (rule if_live_then_nonz_capE')
   apply fastforce
  by (fastforce simp: pred_tcb_at'_def obj_at'_def ko_wp_at'_def)

(* Ugh, required to be able to split out the abstract invs *)
lemma finaliseCap_True_invs'[wp]:
  "\<lbrace>invs'\<rbrace> finaliseCap cap final True \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp add: finaliseCap_def Let_def)
  apply safe
    apply (wp irqs_masked_lift| simp | wpc)+
  done

context begin interpretation Arch . (*FIXME: arch-split*)

lemma invs_asid_update_strg':
  "invs' s \<and> tab = riscvKSASIDTable (ksArchState s) \<longrightarrow>
   invs' (s\<lparr>ksArchState := riscvKSASIDTable_update
            (\<lambda>_. tab (asid := None)) (ksArchState s)\<rparr>)"
  apply (simp add: invs'_def)
  apply (simp add: valid_global_refs'_def global_refs'_def valid_arch_state'_def
                   valid_asid_table'_def valid_machine_state'_def valid_dom_schedule'_def)
  apply (auto simp add: ran_def split: if_split_asm)
  done

lemma deleteASIDPool_invs[wp]:
  "\<lbrace>invs'\<rbrace> deleteASIDPool asid pool \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (simp add: deleteASIDPool_def)
  apply wp
     apply (simp del: fun_upd_apply)
     apply (strengthen invs_asid_update_strg')
     apply (wpsimp wp: mapM_wp' getObject_inv)+
  done

crunch hwASIDFlush
  for irq_masks[wp]: "\<lambda>s. P (irq_masks s)"

lemma dmo_hwASIDFlush_invs[wp]:
  "doMachineOp (hwASIDFlush asid) \<lbrace>invs'\<rbrace>"
  apply (wp dmo_invs')
  apply (clarsimp simp: hwASIDFlush_def machine_op_lift_def machine_rest_lift_def in_monad select_f_def)
  done

lemma deleteASID_invs'[wp]:
  "deleteASID asid pd \<lbrace>invs'\<rbrace>"
  unfolding deleteASID_def by (wpsimp wp: getASID_wp)

lemma arch_finaliseCap_invs[wp]:
  "\<lbrace>invs' and valid_cap' (ArchObjectCap cap)\<rbrace>
     Arch.finaliseCap cap fin
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
  unfolding RISCV64_H.finaliseCap_def by wpsimp

crunch setVMRoot, deleteASIDPool
  for ctes_of[wp]: "\<lambda>s. P (ctes_of s)"
  (wp: crunch_wps getObject_inv getASID_wp simp: crunch_simps)

lemma deleteASID_ctes_of[wp]:
  "deleteASID a ptr \<lbrace>\<lambda>s. P (ctes_of s)\<rbrace>"
  unfolding deleteASID_def by (wpsimp wp: getASID_wp)

lemma arch_finaliseCap_removeable[wp]:
  "\<lbrace>\<lambda>s. s \<turnstile>' ArchObjectCap cap \<and> invs' s
       \<and> (final \<and> final_matters' (ArchObjectCap cap)
            \<longrightarrow> isFinal (ArchObjectCap cap) slot (cteCaps_of s))\<rbrace>
     Arch.finaliseCap cap final
   \<lbrace>\<lambda>rv s. isNullCap (fst rv) \<and> removeable' slot s (ArchObjectCap cap)
          \<and> (snd rv \<noteq> NullCap \<longrightarrow> snd rv = (ArchObjectCap cap) \<and> cap_has_cleanup' (ArchObjectCap cap)
                                      \<and> isFinal (ArchObjectCap cap) slot (cteCaps_of s))\<rbrace>"
  apply (simp add: RISCV64_H.finaliseCap_def removeable'_def)
  apply (wpsimp wp: cteCaps_of_ctes_of_lift)
  done

lemma isZombie_Null:
  "\<not> isZombie NullCap"
  by (simp add: isCap_simps)

lemma prepares_delete_helper'':
  assumes x: "\<lbrace>P\<rbrace> f \<lbrace>\<lambda>rv. ko_wp_at' (Not \<circ> live') p\<rbrace>"
  shows      "\<lbrace>P and K ((\<forall>x. cte_refs' cap x = {})
                          \<and> zobj_refs' cap = {p}
                          \<and> threadCapRefs cap = {})\<rbrace>
                 f \<lbrace>\<lambda>rv s. removeable' sl s cap\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (rule hoare_strengthen_post [OF x])
  apply (clarsimp simp: removeable'_def)
  done

crunch finaliseCapTrue_standin, unbindNotification
  for ctes_of[wp]: "\<lambda>s. P (ctes_of s)"
  (wp: crunch_wps getObject_inv simp: crunch_simps)

lemma cteDeleteOne_cteCaps_of:
  "\<lbrace>\<lambda>s. (cte_wp_at' (\<lambda>cte. \<exists>final. finaliseCap (cteCap cte) final True \<noteq> fail) p s \<longrightarrow>
          P ((cteCaps_of s)(p \<mapsto> NullCap)))\<rbrace>
     cteDeleteOne p
   \<lbrace>\<lambda>rv s. P (cteCaps_of s)\<rbrace>"
  apply (simp add: cteDeleteOne_def unless_def split_def)
  apply (rule bind_wp [OF _ getCTE_sp])
  apply (case_tac "\<forall>final. finaliseCap (cteCap cte) final True = fail")
   apply (simp add: finaliseCapTrue_standin_simple_def)
   apply wp
   apply (clarsimp simp: cte_wp_at_ctes_of cteCaps_of_def
                         finaliseCap_def isCap_simps)
   apply (drule_tac x=s in fun_cong)
   apply (simp add: return_def fail_def)
  apply (wp emptySlot_cteCaps_of)
    apply (simp add: cteCaps_of_def)
    apply (wp (once) hoare_drop_imps)
    apply (wp isFinalCapability_inv getCTE_wp')+
  apply (clarsimp simp: cteCaps_of_def cte_wp_at_ctes_of)
  apply (auto simp: fun_upd_idem fun_upd_def[symmetric] o_def)
  done

lemma cteDeleteOne_isFinal:
  "\<lbrace>\<lambda>s. isFinal cap slot (cteCaps_of s)\<rbrace>
     cteDeleteOne p
   \<lbrace>\<lambda>rv s. isFinal cap slot (cteCaps_of s)\<rbrace>"
  apply (wp cteDeleteOne_cteCaps_of)
  apply (clarsimp simp: isFinal_def sameObjectAs_def2)
  done

lemmas setEndpoint_cteCaps_of[wp] = ctes_of_cteCaps_of_lift [OF set_ep'.ctes_of]
lemmas setNotification_cteCaps_of[wp] = ctes_of_cteCaps_of_lift [OF set_ntfn'.ctes_of]
lemmas setSchedContext_cteCaps_of[wp] = ctes_of_cteCaps_of_lift [OF set_sc'.ctes_of]
lemmas setReply_cteCaps_of[wp] = ctes_of_cteCaps_of_lift [OF set_reply'.ctes_of]
lemmas sts_cteCaps_of[wp] = ctes_of_cteCaps_of_lift[OF setThreadState_ctes_of]

lemmas replyRemoveTCB_cteCaps_of[wp] = ctes_of_cteCaps_of_lift[OF replyRemoveTCB_ctes_of]

crunch suspend, prepareThreadDelete, schedContextUnbindTCB, schedContextCompleteYieldTo,
         unbindFromSC
  for isFinal[wp]: "\<lambda>s. isFinal cap slot (cteCaps_of s)"
  (ignore: threadSet
       wp: threadSet_cteCaps_of crunch_wps
     simp: crunch_simps)

lemma isThreadCap_threadCapRefs_tcbptr:
  "isThreadCap cap \<Longrightarrow> threadCapRefs cap = {capTCBPtr cap}"
  by (clarsimp simp: isCap_simps)

lemma isArchObjectCap_Cap_capCap:
  "isArchObjectCap cap \<Longrightarrow> ArchObjectCap (capCap cap) = cap"
  by (clarsimp simp: isCap_simps)

lemma cteDeleteOne_deletes[wp]:
  "\<lbrace>\<top>\<rbrace> cteDeleteOne p \<lbrace>\<lambda>rv s. cte_wp_at' (\<lambda>c. cteCap c = NullCap) p s\<rbrace>"
  apply (subst tree_cte_cteCap_eq[unfolded o_def])
  apply (wp cteDeleteOne_cteCaps_of)
  apply clarsimp
  done

lemma deletingIRQHandler_removeable':
  "\<lbrace>invs' and (\<lambda>s. isFinal (IRQHandlerCap irq) slot (cteCaps_of s))
          and K (cap = IRQHandlerCap irq)\<rbrace>
     deletingIRQHandler irq
   \<lbrace>\<lambda>rv s. removeable' slot s cap\<rbrace>"
  apply (rule hoare_gen_asm)
  apply (simp add: deletingIRQHandler_def getIRQSlot_def locateSlot_conv
                   getInterruptState_def getSlotCap_def)
  apply (simp add: removeable'_def tree_cte_cteCap_eq[unfolded o_def])
  apply (subst tree_cte_cteCap_eq[unfolded o_def])+
  apply (wp hoare_use_eq_irq_node' [OF cteDeleteOne_irq_node' cteDeleteOne_cteCaps_of]
            getCTE_wp')
  apply (clarsimp simp: cte_level_bits_def ucast_nat_def shiftl_t2n mult_ac cteSizeBits_def
                  split: option.split_asm)
  done

lemma finaliseCap_cte_refs:
  "\<lbrace>\<lambda>s. s \<turnstile>' cap\<rbrace>
     finaliseCap cap final flag
   \<lbrace>\<lambda>rv s. fst rv \<noteq> NullCap \<longrightarrow> cte_refs' (fst rv) = cte_refs' cap\<rbrace>"
  apply (simp  add: finaliseCap_def Let_def getThreadCSpaceRoot
                    RISCV64_H.finaliseCap_def
             cong: if_cong split del: if_split)
  apply (rule hoare_pre)
   apply (wp | wpc | simp only: o_def)+
  apply (frule valid_capAligned)
  apply (cases cap, simp_all add: isCap_simps)
   apply (clarsimp simp: tcb_cte_cases_def word_count_from_top objBits_defs)
  apply clarsimp
  apply (rule ext, simp)
  apply (rule image_cong [OF _ refl])
  apply (fastforce simp: mask_def capAligned_def objBits_simps shiftL_nat)
  done

lemma deletingIRQHandler_final:
  "\<lbrace>\<lambda>s. isFinal cap slot (cteCaps_of s)
             \<and> (\<forall>final. finaliseCap cap final True = fail)\<rbrace>
     deletingIRQHandler irq
   \<lbrace>\<lambda>rv s. isFinal cap slot (cteCaps_of s)\<rbrace>"
  apply (simp add: deletingIRQHandler_def isFinal_def getIRQSlot_def
                   getInterruptState_def locateSlot_conv getSlotCap_def)
  apply (wp cteDeleteOne_cteCaps_of getCTE_wp')
  apply (auto simp: sameObjectAs_def3)
  done

declare suspend_unqueued [wp]

lemma unbindNotification_valid_objs'_helper:
  "valid_tcb' tcb s \<longrightarrow> valid_tcb' (tcbBoundNotification_update (\<lambda>_. None) tcb) s "
  by (clarsimp simp: valid_bound_ntfn'_def valid_tcb'_def tcb_cte_cases_def cteSizeBits_def
                  split: option.splits ntfn.splits)

lemma unbindNotification_valid_objs'_helper':
  "valid_ntfn' tcb s \<longrightarrow> valid_ntfn' (ntfnBoundTCB_update (\<lambda>_. None) tcb) s "
  by (clarsimp simp: valid_bound_tcb'_def valid_ntfn'_def
                  split: option.splits ntfn.splits)

lemma unbindNotification_valid_objs'[wp]:
  "\<lbrace>valid_objs'\<rbrace>
     unbindNotification t
   \<lbrace>\<lambda>rv. valid_objs'\<rbrace>"
  apply (simp add: unbindNotification_def)
  apply (rule hoare_pre)
  apply (wp threadSet_valid_objs' gbn_wp' set_ntfn_valid_objs' hoare_vcg_all_lift getNotification_wp
        | wpc | clarsimp simp: setBoundNotification_def unbindNotification_valid_objs'_helper)+
  apply (clarsimp elim!: obj_atE')
  apply (rule valid_objsE', assumption+)
  apply (clarsimp simp: valid_obj'_def unbindNotification_valid_objs'_helper')
  done

lemma unbindMaybeNotification_valid_tcbs'[wp]:
  "unbindMaybeNotification t \<lbrace>valid_tcbs'\<rbrace>"
  unfolding unbindMaybeNotification_def
  by (wp threadSet_valid_tcbs'
      | wpc | clarsimp simp: setBoundNotification_def unbindNotification_valid_objs'_helper)+

lemma unbindMaybeNotification_valid_objs'[wp]:
  "\<lbrace>valid_objs'\<rbrace>
     unbindMaybeNotification t
   \<lbrace>\<lambda>rv. valid_objs'\<rbrace>"
  apply (simp add: unbindMaybeNotification_def)
  apply (rule bind_wp[OF _ get_ntfn_sp'])
  apply (rule hoare_pre)
  apply (wp threadSet_valid_objs' gbn_wp' set_ntfn_valid_objs' hoare_vcg_all_lift getNotification_wp
        | wpc | clarsimp simp: setBoundNotification_def unbindNotification_valid_objs'_helper)+
  apply (clarsimp elim!: obj_atE')
  apply (rule valid_objsE', assumption+)
  apply (clarsimp simp: valid_obj'_def unbindNotification_valid_objs'_helper')
  done

lemma unbindMaybeNotification_sch_act_wf[wp]:
  "\<lbrace>\<lambda>s. sch_act_wf (ksSchedulerAction s) s\<rbrace> unbindMaybeNotification t
  \<lbrace>\<lambda>rv s. sch_act_wf (ksSchedulerAction s) s\<rbrace>"
  apply (simp add: unbindMaybeNotification_def)
  apply (rule hoare_pre)
  apply (wp sbn_sch_act' | wpc | simp)+
  done

lemma valid_cong:
  "\<lbrakk> \<And>s. P s = P' s; \<And>s. P' s \<Longrightarrow> f s = f' s;
        \<And>rv s' s. \<lbrakk> (rv, s') \<in> fst (f' s); P' s \<rbrakk> \<Longrightarrow> Q rv s' = Q' rv s' \<rbrakk>
    \<Longrightarrow> \<lbrace>P\<rbrace> f \<lbrace>Q\<rbrace> = \<lbrace>P'\<rbrace> f' \<lbrace>Q'\<rbrace>"
  by (clarsimp simp add: valid_def, blast)

lemma unbindMaybeNotification_obj_at'_ntfnBound:
  "\<lbrace>\<top>\<rbrace>
   unbindMaybeNotification r
   \<lbrace>\<lambda>_ s. obj_at' (\<lambda>ntfn. ntfnBoundTCB ntfn = None) r s\<rbrace>"
  apply (simp add: unbindMaybeNotification_def)
  apply (rule bind_wp[OF _ get_ntfn_sp'])
  apply (rule hoare_pre)
   apply (wp obj_at_setObject2
        | wpc
        | simp add: setBoundNotification_def threadSet_def updateObject_default_def in_monad)+
  apply (simp add: setNotification_def obj_at'_real_def cong: valid_cong)
   apply (wp setObject_ko_wp_at, (simp add: objBits_simps')+)
  apply (clarsimp simp: obj_at'_def ko_wp_at'_def)
  done

lemma unbindMaybeNotification_obj_at'_no_change:
  "\<forall>ntfn tcb. P ntfn = P (ntfn \<lparr>ntfnBoundTCB := tcb\<rparr>)
   \<Longrightarrow> unbindMaybeNotification r \<lbrace>obj_at' P r'\<rbrace>"
  apply (simp add: unbindMaybeNotification_def)
  apply (rule bind_wp[OF _ get_ntfn_sp'])
  apply (rule hoare_pre)
   apply (wp obj_at_setObject2
        | wpc
        | simp add: setBoundNotification_def threadSet_def updateObject_default_def in_monad)+
  apply (simp add: setNotification_def obj_at'_real_def cong: valid_cong)
   apply (wp setObject_ko_wp_at, (simp add: objBits_simps')+)
  apply (clarsimp simp: obj_at'_def ko_wp_at'_def)
  done

crunch unbindNotification, unbindMaybeNotification
  for isFinal[wp]: "\<lambda>s. isFinal cap slot (cteCaps_of s)"
  (wp: sts_bound_tcb_at' threadSet_cteCaps_of crunch_wps getObject_inv
   ignore: threadSet
   simp: setBoundNotification_def)

crunch cancelSignal, cancelAllIPC
  for bound_tcb_at'[wp]: "bound_tcb_at' P t"
  and bound_sc_tcb_at'[wp]: "bound_sc_tcb_at' P t"
  (wp: sts_bound_tcb_at' threadSet_cteCaps_of crunch_wps getObject_inv
   ignore: threadSet)

lemma schedContextUnbindTCB_invs'_helper:
  "\<lbrace>\<lambda>s. invs' s \<and> valid_idle' s \<and> cur_tcb' s \<and> scPtr \<noteq> idle_sc_ptr
                \<and> ko_at' sc scPtr s
                \<and> scTCB sc = Some tcbPtr
                \<and> bound_sc_tcb_at' ((=) (Some scPtr)) tcbPtr s\<rbrace>
   do threadSet (tcbSchedContext_update (\<lambda>_. Nothing)) tcbPtr;
      setSchedContext scPtr $ scTCB_update (\<lambda>_. Nothing) sc
   od
   \<lbrace>\<lambda>_. invs'\<rbrace>"
  unfolding schedContextUnbindTCB_def invs'_def
  apply (wp threadSet_not_inQ threadSet_idle' threadSet_iflive' threadSet_ifunsafe'T
            threadSet_valid_pspace'T threadSet_sch_actT_P[where P=False, simplified]
            threadSet_ctes_ofT threadSet_ct_idle_or_in_cur_domain' threadSet_cur
            threadSet_global_refsT irqs_masked_lift untyped_ranges_zero_lift
            valid_irq_node_lift valid_irq_handlers_lift''
            sym_heap_sched_pointers_lift threadSet_tcbSchedNexts_of threadSet_tcbSchedPrevs_of
            threadSet_tcbInReleaseQueue threadSet_tcbQueued valid_bitmaps_lift
            threadSet_valid_sched_pointers
         | (rule hoare_vcg_conj_lift, rule threadSet_wp)
         | clarsimp simp: tcb_cte_cases_def cteSizeBits_def cteCaps_of_def valid_dom_schedule'_def)+
  apply (frule ko_at_valid_objs'_pre[where p=scPtr], clarsimp)
  (* slow 60s *)
  by (auto elim!: ex_cap_to'_after_update[OF if_live_state_refsE[where p=scPtr]]
            elim: valid_objs_sizeE'[OF valid_objs'_valid_objs_size'] ps_clear_domE
           split: option.splits
            simp: pred_tcb_at'_def ko_wp_at'_def obj_at'_def objBits_def objBitsKO_def refillSize_def
                  tcb_cte_cases_def cteSizeBits_def valid_sched_context'_def valid_sched_context_size'_def
                  valid_bound_obj'_def valid_obj'_def valid_obj_size'_def valid_idle'_def
                  valid_pspace'_def untyped_ranges_zero_inv_def
                  idle_tcb'_def state_refs_of'_def comp_def valid_idle'_asrt_def)

crunch tcbReleaseRemove, tcbSchedDequeue
  for cur_tcb'[wp]: cur_tcb'
  (wp: cur_tcb_lift)

lemma schedContextUnbindTCB_invs'[wp]:
  "\<lbrace>\<lambda>s. invs' s \<and> scPtr \<noteq> idle_sc_ptr\<rbrace> schedContextUnbindTCB scPtr \<lbrace>\<lambda>_. invs'\<rbrace>"
  unfolding schedContextUnbindTCB_def
  apply (rule schedContextUnbindTCB_invs'_helper[simplified] bind_wp | clarsimp)+
        apply (wpsimp wp: tcbReleaseRemove_invs' tcbSchedDequeue_invs' hoare_vcg_all_lift)+
  apply (fastforce dest: sym_refs_obj_atD'
                   simp: invs_valid_objs' invs'_valid_tcbs' valid_idle'_asrt_def
                         sym_refs_asrt_def if_cancel_eq_True ko_wp_at'_def refs_of_rev'
                         pred_tcb_at'_def obj_at'_def cur_tcb'_asrt_def)
  done

(* FIXME RT: bound_tcb_at' is an outdated name? *)
lemma threadSet_sc_bound_tcb_at'[wp]:
  "threadSet (tcbSchedContext_update f) t' \<lbrace>bound_tcb_at' P t\<rbrace>"
  by (wpsimp wp: threadSet_pred_tcb_no_state)

lemma threadSet_fault_bound_tcb_at'[wp]:
  "threadSet (tcbFault_update f) t' \<lbrace>bound_tcb_at' P t\<rbrace>"
  by (wpsimp wp: threadSet_pred_tcb_no_state)

crunch replyClear
  for bound_tcb_at'[wp]: "bound_tcb_at' P t"
  (wp: crunch_wps simp: crunch_simps ignore: threadSet)

lemma finaliseCapTrue_standin_bound_tcb_at':
  "\<lbrace>\<lambda>s. bound_tcb_at' P t s \<and> (\<exists>tt r. cap = ReplyCap tt r) \<rbrace>
     finaliseCapTrue_standin cap final
   \<lbrace>\<lambda>_. bound_tcb_at' P t\<rbrace>"
  apply (case_tac cap; simp add: finaliseCapTrue_standin_def isCap_simps)
  by wpsimp

lemma capDeleteOne_bound_tcb_at':
  "\<lbrace>bound_tcb_at' P tptr and cte_wp_at' (isReplyCap \<circ> cteCap) callerCap\<rbrace>
   cteDeleteOne callerCap
   \<lbrace>\<lambda>_. bound_tcb_at' P tptr\<rbrace>"
  apply (simp add: cteDeleteOne_def unless_def)
  apply (rule hoare_pre)
    apply (wp finaliseCapTrue_standin_bound_tcb_at' hoare_vcg_all_lift
              hoare_vcg_if_lift2 getCTE_cteCap_wp
           | clarsimp simp: isFinalCapability_def Let_def cteCaps_of_def isReplyCap_def
                            cte_wp_at_ctes_of
                     split: option.splits
           | intro conjI impI | wp (once) hoare_drop_imp)+
   apply (case_tac "cteCap cte", simp_all)
   done

crunch cleanReply
  for bound_sc_tcb_at'[wp]: "bound_sc_tcb_at' P t"

lemma replyRemoveTCB_bound_sc_tcb_at'[wp]:
  "replyRemoveTCB t \<lbrace>bound_sc_tcb_at' P tptr\<rbrace>"
  unfolding replyRemoveTCB_def
  by (wpsimp wp: hoare_drop_imp hoare_vcg_all_lift threadSet_pred_tcb_no_state)

lemma schedContextCancelYieldTo_bound_tcb_at[wp]:
  "schedContextCancelYieldTo t \<lbrace> bound_tcb_at' P tptr \<rbrace>"
  unfolding schedContextCancelYieldTo_def
  by (wpsimp wp: threadSet_pred_tcb_no_state hoare_vcg_if_lift2 hoare_drop_imp)

crunch prepareThreadDelete
  for pred_tcb_at'[wp]: "pred_tcb_at' proj P t"

crunch suspend
  for bound_tcb_at'[wp]: "bound_tcb_at' P t"
  and bound_sc_tcb_at'[wp]: "bound_sc_tcb_at' P t"
  (wp: threadSet_pred_tcb_no_state crunch_wps simp: crunch_simps)

lemma schedContextCancelYieldTo_bound_yt_tcb_at'_None:
  "\<lbrace>\<lambda>_. True\<rbrace> schedContextCancelYieldTo t \<lbrace>\<lambda>rv. bound_yt_tcb_at' ((=) None) t\<rbrace>"
  apply (simp add: schedContextCancelYieldTo_def)
  apply (wpsimp wp: threadSet_pred_tcb_at_state threadGet_wp)
  apply (auto simp: pred_tcb_at'_def obj_at'_def)
  done

lemma suspend_bound_yt_tcb_at'_None:
  "\<lbrace>\<lambda>_. True\<rbrace> suspend t \<lbrace>\<lambda>rv. bound_yt_tcb_at' ((=) None) t\<rbrace>"
  apply (simp add: suspend_def)
  apply (wpsimp wp: schedContextCancelYieldTo_bound_yt_tcb_at'_None)
  done

crunch schedContextCancelYieldTo
  for tcbSchedNext_tcbSchedPrev[wp]:
    "\<lambda>s. obj_at' (\<lambda>tcb. Q (tcbSchedNext tcb) (tcbSchedPrev tcb)) ptr s"

crunch cancelIPC, updateRestartPC
  for valid_sched_pointers[wp]: valid_sched_pointers
  and sym_heap_sched_pointers[wp]: sym_heap_sched_pointers
  (wp: crunch_wps threadSet_valid_sched_pointers threadSet_sched_pointers ignore: threadSet)

lemma tcbSchedDequeue_tcbQueued_False[wp]:
  "\<lbrace>\<top>\<rbrace> tcbSchedDequeue t \<lbrace>\<lambda>_ s. \<not> (tcbQueued |< tcbs_of' s) t\<rbrace>"
  apply (clarsimp simp: tcbSchedDequeue_def)
  apply (wpsimp wp: threadSet_wp threadGet_wp)
  apply normalise_obj_at'
  apply (force simp: obj_at'_def opt_pred_def opt_map_def)
  done

lemma tcbQueueRemove_tcbSchedNext_tcbSchedPrev_None:
  "\<lbrace>\<lambda>s. \<exists>ts. list_queue_relation ts q (tcbSchedNexts_of s) (tcbSchedPrevs_of s)\<rbrace>
   tcbQueueRemove q t
   \<lbrace>\<lambda>_ s. obj_at' (\<lambda>tcb. tcbSchedNext tcb = None \<and> tcbSchedPrev tcb = None) t s\<rbrace>"
  apply (clarsimp simp: tcbQueueRemove_def)
  apply (wpsimp wp: threadSet_wp getTCB_wp)
  by (fastforce dest!: heap_ls_last_None
                 simp: list_queue_relation_def prev_queue_head_def queue_end_valid_def
                       obj_at'_def opt_map_def ps_clear_def objBits_simps
                split: if_splits)

lemma tcbReleaseRemove_tcbSchedNext_tcbSchedPrev_None:
  "\<lbrace>\<lambda>s. valid_sched_pointers s \<and> \<not> (tcbQueued |< tcbs_of' s) t\<rbrace>
   tcbReleaseRemove t
   \<lbrace>\<lambda>_. obj_at' (\<lambda>tcb. tcbSchedNext tcb = None \<and> tcbSchedPrev tcb = None) t\<rbrace>"
  apply (clarsimp simp: tcbReleaseRemove_def)
  apply (wpsimp wp: tcbQueueRemove_tcbSchedNext_tcbSchedPrev_None inReleaseQueue_wp)
  apply (clarsimp simp: valid_sched_pointers_def)
  apply (drule_tac x=t in spec)
  apply (fastforce simp: ksReleaseQueue_asrt_def opt_pred_def obj_at'_def opt_map_def)
  done

lemma suspend_tcbSchedNext_tcbSchedPrev_None:
  "\<lbrace>invs'\<rbrace> suspend t \<lbrace>\<lambda>_ s. obj_at' (\<lambda>tcb. tcbSchedNext tcb = None \<and> tcbSchedPrev tcb = None) t s\<rbrace>"
  apply (clarsimp simp: suspend_def)
  apply (wpsimp wp: tcbQueueRemove_tcbSchedNext_tcbSchedPrev_None
                    tcbReleaseRemove_tcbSchedNext_tcbSchedPrev_None hoare_drop_imps
         | strengthen invs_sym_heap_sched_pointers)+
  done

crunch schedContextCompleteYieldTo
  for bound_sc_tcb_at'[wp]: "bound_sc_tcb_at' P p"
  and sch_act_simple[wp]: sch_act_simple
  (simp: crunch_simps dxo_wp_weak sch_act_simple_def wp: crunch_wps)

lemma bound_sc_tcb_at'_sym_refsD:
  "\<lbrakk>bound_sc_tcb_at' (\<lambda>scPtr'. scPtr' = Some scPtr) tcbPtr s; sym_refs (state_refs_of' s)\<rbrakk>
   \<Longrightarrow> obj_at' (\<lambda>sc. scTCB sc = Some tcbPtr) scPtr s"
  apply (clarsimp simp: pred_tcb_at'_def)
  apply (drule (1) sym_refs_obj_atD')
  apply (auto simp: state_refs_of'_def ko_wp_at'_def obj_at'_def refs_of_rev' tcb_bound_refs'_def)
  done

lemma schedContextUnbindTCB_bound_sc_tcb_at'_None:
  "\<lbrace>bound_sc_tcb_at' (\<lambda>sc_opt. sc_opt = (Some sc)) t\<rbrace>
   schedContextUnbindTCB sc
   \<lbrace>\<lambda>rv. bound_sc_tcb_at' ((=) None) t\<rbrace>"
  apply (simp add: schedContextUnbindTCB_def sym_refs_asrt_def)
  apply (wpsimp wp: threadSet_pred_tcb_at_state hoare_vcg_imp_lift)
  apply (drule (1) bound_sc_tcb_at'_sym_refsD)
  apply (auto simp: obj_at'_def)
  done

lemma unbindFromSC_bound_sc_tcb_at'_None:
  "\<lbrace>\<top>\<rbrace>
   unbindFromSC t
   \<lbrace>\<lambda>rv. bound_sc_tcb_at' ((=) None) t\<rbrace>"
  apply (simp add: unbindFromSC_def)
  apply (rule bind_wp[OF _ stateAssert_sp])
  apply (wpsimp wp: schedContextUnbindTCB_bound_sc_tcb_at'_None threadGet_wp get_sc_inv'
                    hoare_drop_imp)
  apply (auto simp: pred_tcb_at'_def obj_at'_def)
  done

lemma unbindNotification_bound_tcb_at':
  "\<lbrace>\<lambda>_. True\<rbrace> unbindNotification t \<lbrace>\<lambda>rv. bound_tcb_at' ((=) None) t\<rbrace>"
  apply (simp add: unbindNotification_def)
  apply (wp setBoundNotification_bound_tcb gbn_wp' | wpc | simp)+
  done

crunch unbindNotification, unbindMaybeNotification
  for sym_heap_sched_pointers[wp]: sym_heap_sched_pointers
  and valid_sched_pointers[wp]: valid_sched_pointers
  (wp: threadSet_sched_pointers)

crunch unbindNotification, unbindMaybeNotification
  for weak_sch_act_wf[wp]: "\<lambda>s. weak_sch_act_wf (ksSchedulerAction s) s"
  (wp: weak_sch_act_wf_lift)

lemma unbindNotification_tcb_at'[wp]:
  "\<lbrace>tcb_at' t'\<rbrace> unbindNotification t \<lbrace>\<lambda>rv. tcb_at' t'\<rbrace>"
  apply (simp add: unbindNotification_def)
  apply (wp gbn_wp' | wpc | simp)+
  done

lemma unbindMaybeNotification_tcb_at'[wp]:
  "\<lbrace>tcb_at' t'\<rbrace> unbindMaybeNotification t \<lbrace>\<lambda>rv. tcb_at' t'\<rbrace>"
  apply (simp add: unbindMaybeNotification_def)
  apply (wp gbn_wp' | wpc | simp)+
  done

crunch prepareThreadDelete
  for cte_wp_at'[wp]: "cte_wp_at' P p"
crunch prepareThreadDelete
  for valid_cap'[wp]: "valid_cap' cap"
crunch prepareThreadDelete
  for invs[wp]: "invs'" (ignore: doMachineOp)
crunch prepareThreadDelete
  for obj_at'[wp]: "\<lambda>s. P' (obj_at' P p s)"
  (wp: whenE_wp simp: crunch_simps)

end

lemma ntfnSc_sym_refsD:
  "\<lbrakk>obj_at' (\<lambda>ntfn. ntfnSc ntfn = Some scPtr) ntfnPtr s; sym_refs (state_refs_of' s)\<rbrakk>
    \<Longrightarrow> obj_at' (\<lambda>sc. scNtfn sc = Some ntfnPtr) scPtr s"
  apply (drule (1) sym_refs_obj_atD')
  apply (auto simp: state_refs_of'_def ko_wp_at'_def obj_at'_def refs_of_rev')
  done

lemma scNtfn_sym_refsD:
  "\<lbrakk>obj_at' (\<lambda>sc. scNtfn sc = Some ntfnPtr) scPtr s;
    valid_objs' s; sym_refs (state_refs_of' s)\<rbrakk>
    \<Longrightarrow> obj_at' (\<lambda>ntfn. ntfnSc ntfn = Some scPtr) ntfnPtr s"
  apply (frule obj_at_valid_objs', assumption)
  apply (clarsimp simp: valid_obj'_def valid_sched_context'_def)
  apply (frule_tac p=ntfnPtr in obj_at_valid_objs', assumption)
  apply (clarsimp simp: valid_obj'_def valid_ntfn'_def)
  apply (frule_tac p=scPtr in sym_refs_obj_atD', assumption)
  apply (frule_tac p=ntfnPtr in sym_refs_obj_atD', assumption)
  apply (clarsimp simp: ko_wp_at'_def obj_at'_def get_refs_def2 ntfn_q_refs_of'_def
                 split: Structures_H.ntfn.splits)
  done

lemma schedContextUnbindNtfn_obj_at'_ntfnSc:
  "\<lbrace>obj_at' (\<lambda>ntfn. ntfnSc ntfn = Some scPtr) ntfnPtr\<rbrace>
   schedContextUnbindNtfn scPtr
   \<lbrace>\<lambda>_ s. obj_at' (\<lambda>ntfn. ntfnSc ntfn = None) ntfnPtr s\<rbrace>"
  apply (simp add: schedContextUnbindNtfn_def sym_refs_asrt_def)
  apply (wpsimp wp: stateAssert_wp set_ntfn'.obj_at'_strongest getNotification_wp
                    hoare_vcg_all_lift hoare_vcg_imp_lift')
  apply (drule ntfnSc_sym_refsD; assumption?)
  apply (clarsimp simp: obj_at'_def)
  done

lemma schedContextMaybeUnbindNtfn_obj_at'_ntfnSc:
  "\<lbrace>\<top>\<rbrace>
   schedContextMaybeUnbindNtfn ntfnPtr
   \<lbrace>\<lambda>_ s. obj_at' (\<lambda>ntfn. ntfnSc ntfn = None) ntfnPtr s\<rbrace>"
  apply (simp add: schedContextMaybeUnbindNtfn_def)
  apply (wpsimp wp: schedContextUnbindNtfn_obj_at'_ntfnSc getNotification_wp)
  apply (clarsimp simp: obj_at'_def)
  done

lemma replyUnlink_makes_unlive:
  "\<lbrace>\<lambda>s. \<not> is_reply_linked rptr' s \<and> replySCs_of s rptr' = None \<and> rptr' = rptr\<rbrace>
   replyUnlink rptr tptr
   \<lbrace>\<lambda>_. ko_wp_at' (Not \<circ> live') rptr'\<rbrace>"
  supply fun_upd_apply[simp del]
  apply (clarsimp simp: replyUnlink_def updateReply_def)
  apply (wpsimp wp: setThreadState_Inactive_unlive)
         apply (wpsimp wp: set_reply'.set_wp)
        apply (wpsimp wp: gts_wp')+
  by (auto simp: fun_upd_apply ko_wp_at'_def obj_at'_def opt_map_def objBitsKO_def
                 live_reply'_def weak_sch_act_wf_def pred_tcb_at'_def
                 replyNext_None_iff)

lemma cleanReply_obj_at_next_prev_none:
  "\<lbrace>K (rptr' = rptr)\<rbrace>
   cleanReply rptr
   \<lbrace>\<lambda>_ s. \<not> is_reply_linked rptr s \<and> replySCs_of s rptr = None\<rbrace>"
  apply (simp add: cleanReply_def )
  apply (wpsimp wp: updateReply_wp_all)
  apply (auto simp: obj_at'_def objBitsKO_def)
  done

lemma replyPop_makes_unlive:
  "\<lbrace>\<lambda>s. valid_tcbs' s \<and> sym_heap_sched_pointers s \<and> valid_sched_pointers s\<rbrace>
   replyPop rptr tptr
   \<lbrace>\<lambda>_. ko_wp_at' (Not \<circ> live') rptr\<rbrace>"
  unfolding replyPop_def
  by (wpsimp wp: replyUnlink_makes_unlive cleanReply_obj_at_next_prev_none
                 hoare_vcg_if_lift threadGet_wp hoare_vcg_ex_lift
      | wp (once) hoare_drop_imps)+

lemma replyRemove_makes_unlive:
  "\<lbrace>\<lambda>s. valid_tcbs' s \<and> sym_heap_sched_pointers s \<and> valid_sched_pointers s\<rbrace>
   replyRemove rptr tptr
   \<lbrace>\<lambda>_. ko_wp_at' (Not \<circ> live') rptr\<rbrace>"
  apply (simp add: replyRemove_def)
  by (wpsimp wp: replyPop_makes_unlive replyUnlink_makes_unlive cleanReply_obj_at_next_prev_none
                 hoare_vcg_if_lift threadGet_wp gts_wp' hoare_drop_imps)

lemma replyRemoveTCB_makes_unlive:
  "\<lbrace>\<lambda>s. st_tcb_at' (\<lambda>st. replyObject st = Some rptr) tptr s
        \<and> valid_tcbs' s \<and> sym_heap_sched_pointers s \<and> valid_sched_pointers s\<rbrace>
   replyRemoveTCB tptr
   \<lbrace>\<lambda>_. ko_wp_at' (Not \<circ> live') rptr\<rbrace>"
  apply (simp add: replyRemoveTCB_def)
  apply (wpsimp wp: replyUnlink_makes_unlive cleanReply_obj_at_next_prev_none
                    hoare_vcg_if_lift threadGet_wp gts_wp' hoare_drop_imps)
  by (clarsimp simp: pred_tcb_at'_def obj_at'_def)

method cancelIPC_makes_unlive_hammer =
  (normalise_obj_at',
   frule (2) sym_ref_replyTCB_Receive_or_Reply,
   fastforce simp: weak_sch_act_wf_def pred_tcb_at'_def obj_at'_def)

lemma cancelIPC_makes_unlive:
  "\<lbrace>\<lambda>s. obj_at' (\<lambda>reply. replyTCB reply = Some tptr) rptr s
        \<and> valid_replies' s \<and> valid_replies'_sc_asrt rptr s \<and> valid_tcbs' s
        \<and> sym_heap_sched_pointers s \<and> valid_sched_pointers s\<rbrace>
   cancelIPC tptr
   \<lbrace>\<lambda>_. ko_wp_at' (Not \<circ> live') rptr\<rbrace>"
  unfolding cancelIPC_def blockedCancelIPC_def Let_def getBlockingObject_def sym_refs_asrt_def
  apply simp
  apply (intro bind_wp[OF _ stateAssert_sp] bind_wp[OF _ gts_sp'])+
  apply (case_tac state; clarsimp)
         (* BlockedOnReceive*)
         apply (rename_tac ep pl rp)
         apply (case_tac rp; clarsimp)
          apply (wpsimp wp: hoare_pre_cont, cancelIPC_makes_unlive_hammer)
         apply (wpsimp wp: setThreadState_unlive_other replyUnlink_makes_unlive
                           hoare_vcg_all_lift hoare_drop_imps threadSet_weak_sch_act_wf)
         apply (frule obj_at_replyTCBs_of,
                frule (1) valid_replies'_other_state;
                  clarsimp simp: valid_replies'_sc_asrt_replySC_None)
         apply cancelIPC_makes_unlive_hammer
        (* BlockedOnReply*)
        apply (wpsimp wp: replyRemoveTCB_makes_unlive threadSet_pred_tcb_no_state
                          threadSet_weak_sch_act_wf threadSet_valid_tcbs'
                          threadSet_sched_pointers threadSet_valid_sched_pointers)
        apply cancelIPC_makes_unlive_hammer
       (* All other states are impossible *)
       apply (wpsimp wp: hoare_pre_cont, cancelIPC_makes_unlive_hammer)+
  done

lemma replyClear_makes_unlive:
  "\<lbrace>\<lambda>s. obj_at' (\<lambda>reply. replyTCB reply = Some tptr) rptr s
        \<and> valid_replies' s \<and> valid_replies'_sc_asrt rptr s \<and> valid_tcbs' s
        \<and> sym_heap_sched_pointers s \<and> valid_sched_pointers s\<rbrace>
   replyClear rptr tptr
   \<lbrace>\<lambda>_. ko_wp_at' (Not \<circ> live') rptr\<rbrace>"
  apply (simp add: replyClear_def)
  apply (wpsimp wp: replyRemove_makes_unlive cancelIPC_makes_unlive gts_wp' haskell_fail_wp)
  done

crunch unbindFromSC
  for bound_tcb_at'[wp]: "bound_tcb_at' P p"
  (ignore: threadSet simp: crunch_simps wp: crunch_wps)

crunch setConsumed
  for ksQ[wp]: "\<lambda>s. P (ksReadyQueues s p)"
  (simp: crunch_simps wp: crunch_wps)

crunch schedContextUnbindTCB
  for valid_sched_pointers[wp]: valid_sched_pointers

lemma valid_tcb'_ksMachineState_update[simp]:
  "valid_tcb' tcb (ksMachineState_update f s) = valid_tcb' tcb s"
  by (auto simp: valid_tcb'_def valid_tcb_state'_def valid_bound_obj'_def
          split: option.splits thread_state.splits)

lemma valid_tcbs'_ksMachineState_update[simp]:
  "valid_tcbs' (ksMachineState_update f s) = valid_tcbs' s"
  by (auto simp: valid_tcbs'_def)

lemma schedContextSetInactive_unlive[wp]:
  "schedContextSetInactive scPtr \<lbrace>\<lambda>s. P (ko_wp_at' (Not \<circ> live') p s)\<rbrace>"
  unfolding schedContextSetInactive_def
  apply (wpsimp wp: set_sc'.set_wp simp: updateSchedContext_def simp_del: fun_upd_apply)
  apply (clarsimp simp: ko_wp_at'_def obj_at'_def live_sc'_def
                        ps_clear_upd objBits_simps scBits_simps)
  done

crunch setMessageInfo, setMRs
  for obj_at'_sc[wp]: "obj_at' (P :: sched_context \<Rightarrow> bool) p"
  (wp: crunch_wps simp: crunch_simps)

lemma schedContextUpdateConsumed_obj_at'_not_consumed:
  "(\<And>ko f. P (scConsumed_update f ko) = P ko)
   \<Longrightarrow> schedContextUpdateConsumed scPtr \<lbrace>obj_at' P t\<rbrace>"
  apply (simp add: schedContextUpdateConsumed_def)
  apply (wpsimp wp: set_sc'.obj_at'_strongest)
  by (auto simp: obj_at'_def)

lemma setConsumed_obj_at'_not_consumed:
  "(\<And>ko f. P (scConsumed_update f ko) = P ko)
   \<Longrightarrow> setConsumed scPtr buffer \<lbrace>obj_at' P t\<rbrace>"
  apply (clarsimp simp: setConsumed_def)
  apply (wpsimp wp: schedContextUpdateConsumed_obj_at'_not_consumed)
  done

lemma schedContextCancelYieldTo_makes_unlive:
  "\<lbrace>obj_at' (\<lambda>sc. scTCB sc = None) scPtr and obj_at' (\<lambda>sc. scNtfn sc = None) scPtr and
    obj_at' (\<lambda>sc. scReply sc = None) scPtr and bound_yt_tcb_at' (\<lambda>yieldTo. yieldTo = Some scPtr) tptr\<rbrace>
   schedContextCancelYieldTo tptr
   \<lbrace>\<lambda>_. ko_wp_at' (Not \<circ> live') scPtr\<rbrace>"
  unfolding schedContextCancelYieldTo_def updateSchedContext_def
  apply (wpsimp wp: threadSet_unlive_other set_sc'.ko_wp_at threadGet_wp')
  apply (auto simp: pred_tcb_at'_def obj_at'_def ko_wp_at'_def live_sc'_def)
  done

lemma schedContextCompleteYieldTo_makes_unlive:
  "\<lbrace>obj_at' (\<lambda>sc. scTCB sc = None) scPtr and obj_at' (\<lambda>sc. scNtfn sc = None) scPtr and
    obj_at' (\<lambda>sc. scReply sc = None) scPtr and bound_yt_tcb_at' ((=) (Some scPtr)) tptr\<rbrace>
   schedContextCompleteYieldTo tptr
   \<lbrace>\<lambda>_. ko_wp_at' (Not \<circ> live') scPtr\<rbrace>"
  unfolding schedContextCompleteYieldTo_def
  apply (wpsimp wp: schedContextCancelYieldTo_makes_unlive haskell_fail_wp
                    setConsumed_obj_at'_not_consumed hoare_drop_imps threadGet_wp)
  apply (auto simp: pred_tcb_at'_def obj_at'_def)
  done

lemma sym_ref_scYieldFrom:
  "\<lbrakk>ko_at' sc scp s; scYieldFrom sc = Some tp; sym_refs (state_refs_of' s)\<rbrakk>
  \<Longrightarrow> \<exists>tcb. ko_at' tcb tp s \<and> tcbYieldTo tcb = Some scp"
  apply (drule (1) sym_refs_ko_atD')
  apply (auto simp: state_refs_of'_def ko_wp_at'_def obj_at'_def refs_of_rev')
  done

lemma schedContextUnbindYieldFrom_makes_unlive:
  "\<lbrace>obj_at' (\<lambda>sc. scTCB sc = None) scPtr and obj_at' (\<lambda>sc. scNtfn sc = None) scPtr and
    obj_at' (\<lambda>sc. scReply sc = None) scPtr\<rbrace>
   schedContextUnbindYieldFrom scPtr
   \<lbrace>\<lambda>_. ko_wp_at' (Not \<circ> live') scPtr\<rbrace>"
  unfolding schedContextUnbindYieldFrom_def sym_refs_asrt_def
  apply (wpsimp wp: schedContextCompleteYieldTo_makes_unlive)
  apply (rule conjI; clarsimp)
   apply (drule (2) sym_ref_scYieldFrom)
   apply (auto simp: pred_tcb_at'_def obj_at'_def ko_wp_at'_def live_sc'_def)
  done

lemma schedContextUnbindReply_obj_at'_not_reply:
  "(\<And>ko f. P (scReply_update f ko) = P ko)
   \<Longrightarrow> schedContextUnbindReply scPtr \<lbrace>obj_at' P p\<rbrace>"
  apply (clarsimp simp: schedContextUnbindReply_def)
  apply (wpsimp wp: set_sc'.obj_at'_strongest updateReply_wp_all)
  by (auto simp: obj_at'_def)

lemma schedContextUnbindReply_obj_at'_reply_None:
  "\<lbrace>\<top>\<rbrace> schedContextUnbindReply scPtr \<lbrace>\<lambda>_. obj_at' (\<lambda>sc. scReply sc = None) scPtr\<rbrace>"
  apply (clarsimp simp: schedContextUnbindReply_def)
  apply (wpsimp wp: set_sc'.obj_at'_strongest)
  by (auto simp: obj_at'_def)

lemma schedContextUnbindNtfn_obj_at'_not_ntfn:
  "(\<And>ko f. P (scNtfn_update f ko) = P ko)
   \<Longrightarrow> schedContextUnbindNtfn scPtr \<lbrace>obj_at' P p\<rbrace>"
  apply (clarsimp simp: schedContextUnbindNtfn_def)
  apply (wpsimp wp: set_sc'.obj_at'_strongest set_ntfn'.set_wp getNotification_wp)
  by (auto simp: obj_at'_def)

lemma schedContextUnbindNtfn_obj_at'_ntfn_None:
  "\<lbrace>\<top>\<rbrace> schedContextUnbindNtfn scPtr \<lbrace>\<lambda>_. obj_at' (\<lambda>sc. scNtfn sc = None) scPtr\<rbrace>"
  apply (clarsimp simp: schedContextUnbindNtfn_def)
  apply (wpsimp wp: set_sc'.obj_at'_strongest)
  by (auto simp: obj_at'_def)

lemma schedContextUnbindTCB_obj_at'_tcb_None:
  "\<lbrace>\<top>\<rbrace> schedContextUnbindTCB scPtr \<lbrace>\<lambda>_. obj_at' (\<lambda>sc. scTCB sc = None) scPtr\<rbrace>"
  apply (clarsimp simp: schedContextUnbindTCB_def)
  by (wpsimp wp: set_sc'.obj_at'_strongest)

lemma schedContextUnbindAllTCBs_obj_at'_tcb_None:
  "\<lbrace>\<top>\<rbrace> schedContextUnbindAllTCBs scPtr \<lbrace>\<lambda>_. obj_at' (\<lambda>sc. scTCB sc = None) scPtr\<rbrace>"
  apply (clarsimp simp: schedContextUnbindAllTCBs_def)
  apply (wpsimp wp: schedContextUnbindTCB_obj_at'_tcb_None)
  by (auto simp: obj_at'_def)

lemmas schedContextSetInactive_removeable'
  = prepares_delete_helper'' [OF schedContextSetInactive_unlive
                                   [where p=scPtr and scPtr=scPtr for scPtr]]

crunch schedContextMaybeUnbindNtfn
  for sch_act_wf[wp]: "\<lambda>s. sch_act_wf (ksSchedulerAction s) s"
  and valid_tcbs'[wp]: valid_tcbs'

lemma unbindFromSC_invs'[wp]:
  "\<lbrace>invs' and tcb_at' t and K (t \<noteq> idle_thread_ptr)\<rbrace> unbindFromSC t \<lbrace>\<lambda>_. invs'\<rbrace>"
  apply (clarsimp simp: unbindFromSC_def sym_refs_asrt_def)
  apply (wpsimp split_del: if_split)
     apply (rule_tac Q'="\<lambda>_. sc_at' y and invs'" in hoare_post_imp)
      apply (fastforce simp: valid_obj'_def valid_sched_context'_def
                      dest!: ko_at_valid_objs')
     apply (wpsimp wp: typ_at_lifts threadGet_wp)+
  apply (drule obj_at_ko_at', clarsimp)
  apply (frule ko_at_valid_objs'; clarsimp simp: valid_obj'_def valid_tcb'_def)
  apply (frule sym_refs_tcbSchedContext; assumption?)
  apply (subgoal_tac "ex_nonz_cap_to' idle_sc_ptr s")
   apply (fastforce simp: invs'_def global'_sc_no_ex_cap)
  apply (fastforce intro!: if_live_then_nonz_capE'
                     simp: obj_at'_def ko_wp_at'_def live_sc'_def)
  done

lemma (in delete_one_conc_pre) finaliseCap_replaceable:
  "\<lbrace>\<lambda>s. invs' s \<and> cte_wp_at' (\<lambda>cte. cteCap cte = cap) slot s
       \<and> (final_matters' cap \<longrightarrow> (final = isFinal cap slot (cteCaps_of s)))\<rbrace>
     finaliseCap cap final flag
   \<lbrace>\<lambda>rv s. (isNullCap (fst rv) \<and> removeable' slot s cap
                \<and> (snd rv \<noteq> NullCap \<longrightarrow> snd rv = cap \<and> cap_has_cleanup' cap
                                      \<and> isFinal cap slot (cteCaps_of s)))
        \<or>
          (isZombie (fst rv) \<and> snd rv = NullCap
            \<and> isFinal cap slot (cteCaps_of s)
            \<and> capClass cap = capClass (fst rv)
            \<and> capUntypedPtr (fst rv) = capUntypedPtr cap
            \<and> capBits (fst rv) = capBits cap
            \<and> capRange (fst rv) = capRange cap
            \<and> (isThreadCap cap \<or> isCNodeCap cap \<or> isZombie cap)
            \<and> (\<forall>p \<in> threadCapRefs cap. st_tcb_at' ((=) Inactive) p s
                     \<and> obj_at' (Not \<circ> tcbQueued) p s
                     \<and> obj_at' (Not \<circ> tcbInReleaseQueue) p s
                     \<and> bound_tcb_at' ((=) None) p s
                     \<and> bound_sc_tcb_at' ((=) None) p s
                     \<and> bound_yt_tcb_at' ((=) None) p s
                     \<and> obj_at' (\<lambda>tcb. tcbSchedNext tcb = None \<and> tcbSchedPrev tcb = None) p s))\<rbrace>"
  apply (simp add: finaliseCap_def Let_def getThreadCSpaceRoot
             cong: if_cong split del: if_split)
  apply (rule hoare_pre)
   apply (wpsimp wp: prepares_delete_helper'' [OF cancelAllIPC_unlive]
                     prepares_delete_helper'' [OF cancelAllSignals_unlive]
                     unbindMaybeNotification_obj_at'_ntfnBound
                     unbindMaybeNotification_obj_at'_no_change
               simp: isZombie_Null)
    apply (strengthen invs_valid_objs')
    apply (wpsimp wp: schedContextMaybeUnbindNtfn_obj_at'_ntfnSc
                      prepares_delete_helper'' [OF replyClear_makes_unlive]
                      hoare_vcg_if_lift_strong simp: isZombie_Null)+
        apply (clarsimp simp: obj_at'_def)
       apply (wpsimp wp: schedContextSetInactive_removeable'
                         prepareThreadDelete_unqueued
                         prepareThreadDelete_inactive
                         suspend_makes_inactive
                         suspend_flag_not_set
                         suspend_tcbSchedNext_tcbSchedPrev_None
                         suspend_bound_yt_tcb_at'_None
                         unbindNotification_bound_tcb_at'
                         unbindFromSC_bound_sc_tcb_at'_None
                         schedContextUnbindYieldFrom_makes_unlive
                         schedContextUnbindReply_obj_at'_reply_None
                         schedContextUnbindReply_obj_at'_not_reply
                         schedContextUnbindNtfn_obj_at'_ntfn_None
                         schedContextUnbindNtfn_obj_at'_not_ntfn
                         schedContextUnbindAllTCBs_obj_at'_tcb_None
                   simp: isZombie_Null isThreadCap_threadCapRefs_tcbptr)+
    apply (rule hoare_strengthen_post [OF arch_finaliseCap_removeable[where slot=slot]],
           clarsimp simp: isCap_simps)
   apply (wpsimp wp: deletingIRQHandler_removeable'
                     deletingIRQHandler_final[where slot=slot])+
  apply (frule cte_wp_at_valid_objs_valid_cap'; clarsimp)
  apply (case_tac "cteCap cte",
         simp_all add: isCap_simps capRange_def cap_has_cleanup'_def
                       final_matters'_def objBits_simps
                       not_Final_removeable finaliseCap_def,
         simp_all add: removeable'_def)
     (* ThreadCap *)
      apply (frule capAligned_capUntypedPtr [OF valid_capAligned], simp)
      apply (clarsimp simp: valid_cap'_def)
      apply (drule valid_globals_cte_wpD'_idleThread[rotated], clarsimp)
      apply (fastforce simp: invs'_def valid_pspace'_def valid_idle'_asrt_def valid_idle'_def)
     (* NotificationCap *)
     apply (fastforce simp: obj_at'_def sch_act_wf_asrt_def)
     (* EndpointCap *)
    apply (fastforce simp: sch_act_wf_asrt_def valid_cap'_def)
   (* ArchObjectCap *)
   apply (fastforce simp: obj_at'_def sch_act_wf_asrt_def)
  (* ReplyCap *)
  apply (rule conjI; clarsimp)
   apply (fastforce simp: obj_at'_def sch_act_wf_asrt_def)
  apply (frule (1) obj_at_replyTCBs_of[OF ko_at_obj_at', simplified])
  apply (frule valid_replies'_no_tcb, clarsimp)
  apply (clarsimp simp: ko_wp_at'_def obj_at'_def live_reply'_def opt_map_def
                        valid_replies'_sc_asrt_def replyNext_None_iff)
  done

lemma cteDeleteOne_cte_wp_at_preserved:
  assumes x: "\<And>cap final. P cap \<Longrightarrow> finaliseCap cap final True = fail"
  shows "\<lbrace>\<lambda>s. cte_wp_at' (\<lambda>cte. P (cteCap cte)) p s\<rbrace>
           cteDeleteOne ptr
         \<lbrace>\<lambda>rv s. cte_wp_at' (\<lambda>cte. P (cteCap cte)) p s\<rbrace>"
  apply (simp add: tree_cte_cteCap_eq[unfolded o_def])
  apply (rule hoare_pre, wp cteDeleteOne_cteCaps_of)
  apply (clarsimp simp: cteCaps_of_def cte_wp_at_ctes_of x)
  done

lemma cancelIPC_cteCaps_of[wp]:
  "cancelIPC t \<lbrace>\<lambda>s. P (cteCaps_of s)\<rbrace>"
  apply (simp add: cancelIPC_def Let_def capHasProperty_def locateSlot_conv)
  apply (rule bind_wp_fwd_skip, wpsimp)
  apply (rule bind_wp_fwd_skip, wpsimp)
  apply (rule hoare_pre)
   apply (wp getCTE_wp' | wpcw
          | simp add: cte_wp_at_ctes_of
          | wp (once) hoare_drop_imps ctes_of_cteCaps_of_lift)+
          apply (wp hoare_convert_imp hoare_vcg_all_lift
                    threadSet_ctes_of threadSet_cteCaps_of
               | clarsimp)+
  done

lemma cancelIPC_cte_wp_at'[wp]:
  "cancelIPC t \<lbrace>\<lambda>s. cte_wp_at' (\<lambda>cte. P (cteCap cte)) p s\<rbrace>"
  apply (simp add: tree_cte_cteCap_eq[unfolded o_def])
  apply wpsimp
  done

crunch schedContextCancelYieldTo, tcbReleaseRemove
  for cte_wp_at'[wp]: "cte_wp_at' P p"
  (wp: crunch_wps simp: crunch_simps)

lemma suspend_cte_wp_at':
  "suspend t \<lbrace>cte_wp_at' (\<lambda>cte. P (cteCap cte)) p\<rbrace>"
  unfolding updateRestartPC_def suspend_def
  apply (wpsimp wp: hoare_vcg_imp_lift hoare_disjI2[where Q'="\<lambda>_. cte_wp_at' a b" for a b])
  done

context begin interpretation Arch . (*FIXME: arch-split*)

crunch deleteASIDPool
  for cte_wp_at'[wp]: "cte_wp_at' P p"
  (simp: crunch_simps assertE_def
   wp: crunch_wps getObject_inv)

lemma deleteASID_cte_wp_at'[wp]:
  "\<lbrace>cte_wp_at' P p\<rbrace> deleteASID param_a param_b \<lbrace>\<lambda>_. cte_wp_at' P p\<rbrace>"
  apply (simp add: deleteASID_def
              cong: option.case_cong)
  apply (wp setObject_cte_wp_at'[where Q="\<top>"] getObject_inv setVMRoot_cte_wp_at'
          | clarsimp simp: updateObject_default_def in_monad
          | rule equals0I
          | wpc)+
  done

crunch unmapPageTable, unmapPage, unbindNotification, cancelAllIPC, cancelAllSignals,
         unbindMaybeNotification, schedContextMaybeUnbindNtfn, replyRemove,
         unbindFromSC, schedContextSetInactive, schedContextUnbindYieldFrom,
         schedContextUnbindReply, schedContextUnbindAllTCBs
  for cte_wp_at'[wp]: "cte_wp_at' P p"
  (simp: crunch_simps wp: crunch_wps getObject_inv)

lemma replyClear_standin_cte_preserved[wp]:
  "replyClear rptr tptr \<lbrace>cte_wp_at' (\<lambda>cte. P (cteCap cte)) p\<rbrace>"
  unfolding replyClear_def
  by (wpsimp wp: gts_wp')

lemma finaliseCapTrue_standin_cte_preserved[wp]:
  "finaliseCapTrue_standin cap fin \<lbrace>cte_wp_at' (\<lambda>cte. P (cteCap cte)) p\<rbrace>"
  unfolding finaliseCapTrue_standin_def Let_def
  by (wpsimp wp: replyClear_standin_cte_preserved simp:)

lemma arch_finaliseCap_cte_wp_at[wp]:
  "\<lbrace>cte_wp_at' P p\<rbrace> Arch.finaliseCap cap fin \<lbrace>\<lambda>rv. cte_wp_at' P p\<rbrace>"
  apply (simp add: RISCV64_H.finaliseCap_def)
  apply (wpsimp wp: unmapPage_cte_wp_at')
  done

end

lemma deletingIRQHandler_cte_preserved:
  assumes x: "\<And>cap final. P cap \<Longrightarrow> finaliseCap cap final True = fail"
  shows "\<lbrace>cte_wp_at' (\<lambda>cte. P (cteCap cte)) p\<rbrace>
         deletingIRQHandler irq
         \<lbrace>\<lambda>_. cte_wp_at' (\<lambda>cte. P (cteCap cte)) p\<rbrace>"
  apply (simp add: deletingIRQHandler_def getSlotCap_def
                   getIRQSlot_def locateSlot_conv getInterruptState_def)
  apply (wpsimp wp: cteDeleteOne_cte_wp_at_preserved getCTE_wp' simp: x)
  done

lemma finaliseCap_equal_cap[wp]:
  "\<lbrace>cte_wp_at' (\<lambda>cte. cteCap cte = cap) sl\<rbrace>
   finaliseCap cap fin flag
   \<lbrace>\<lambda>rv. cte_wp_at' (\<lambda>cte. cteCap cte = cap) sl\<rbrace>"
  apply (simp add: finaliseCap_def Let_def
             cong: if_cong split del: if_split)
  apply (wpsimp wp: suspend_cte_wp_at' deletingIRQHandler_cte_preserved
              simp: finaliseCap_def)+
  apply auto
  done

lemma setThreadState_st_tcb_at_simplish':
  "simple' st \<Longrightarrow>
   \<lbrace>st_tcb_at' (P or simple') t\<rbrace>
     setThreadState st t'
   \<lbrace>\<lambda>rv. st_tcb_at' (P or simple') t\<rbrace>"
  apply (wp sts_st_tcb_at'_cases)
  apply clarsimp
  done

lemmas setThreadState_st_tcb_at_simplish
    = setThreadState_st_tcb_at_simplish'[unfolded pred_disj_def]

lemma replyUnlink_st_tcb_at_simplish:
  "replyUnlink r t' \<lbrace>st_tcb_at' (\<lambda>st. P st \<or> simple' st) t\<rbrace>"
  supply if_split [split del]
  unfolding replyUnlink_def
  apply (wpsimp wp: sts_st_tcb' hoare_vcg_if_lift2 hoare_vcg_imp_lift' gts_wp')
  done

crunch cteDeleteOne
 for st_tcb_at_simplish: "st_tcb_at' (\<lambda>st. P st \<or> simple' st) t"
  (wp: crunch_wps getObject_inv threadSet_pred_tcb_no_state
   simp: crunch_simps unless_def ignore: threadSet)

lemma cteDeleteOne_st_tcb_at[wp]:
  assumes x[simp]: "\<And>st. simple' st \<longrightarrow> P st" shows
  "\<lbrace>st_tcb_at' P t\<rbrace> cteDeleteOne slot \<lbrace>\<lambda>rv. st_tcb_at' P t\<rbrace>"
  apply (subgoal_tac "\<exists>Q. P = (Q or simple')")
   apply (clarsimp simp: pred_disj_def)
   apply (rule cteDeleteOne_st_tcb_at_simplish)
  apply (rule_tac x=P in exI)
  apply auto
  done

lemma rescheduleRequired_sch_act_not[wp]:
  "\<lbrace>\<top>\<rbrace> rescheduleRequired \<lbrace>\<lambda>rv. sch_act_not t\<rbrace>"
  apply (simp add: rescheduleRequired_def setSchedulerAction_def)
  apply (wp hoare_TrueI | simp)+
  done

crunch cancelAllIPC, cancelAllSignals, unbindMaybeNotification
  for tcbDomain_obj_at': "obj_at' (\<lambda>tcb. P (tcbDomain tcb)) t'"
  (wp: crunch_wps simp: crunch_simps)

crunch replyUnlink
  for tcbFault_obj_at'[wp]: "obj_at' (\<lambda>tcb. P (tcbFault tcb)) t'"
  (wp: crunch_wps)

lemma setBoundNotification_valid_tcbs'[wp]:
  "\<lbrace>valid_tcbs' and valid_bound_ntfn' ntfn\<rbrace> setBoundNotification ntfn t \<lbrace>\<lambda>rv. valid_tcbs'\<rbrace>"
  apply (wpsimp simp: setBoundNotification_def wp: threadSet_valid_tcbs')
  by (simp add: valid_tcb'_def tcb_cte_cases_def cteSizeBits_def)

lemma setQueue_valid_sched_context'[wp]:
  "setQueue tdom prio q \<lbrace>valid_sched_context' sc\<rbrace>"
  apply (wpsimp simp: setQueue_def valid_sched_context'_def valid_bound_obj'_def
               split: option.splits)
  done

crunch tcbSchedDequeue, tcbSchedEnqueue
  for valid_sched_context'[wp]: "\<lambda>s. valid_sched_context' sc' s"
  (wp: crunch_wps)

lemma setQueue_valid_reply'[wp]:
  "setQueue domain prio q \<lbrace>valid_reply' reply\<rbrace>"
  apply (clarsimp simp: setQueue_def)
  apply wpsimp
  apply (fastforce simp: valid_reply'_def valid_bound_obj'_def split: option.splits)
  done

crunch isFinalCapability
  for sch_act[wp]: "\<lambda>s. sch_act_wf (ksSchedulerAction s) s"
  and weak_sch_act[wp]: "\<lambda>s. weak_sch_act_wf (ksSchedulerAction s) s"
  (simp: crunch_simps)

context begin interpretation Arch .

lemma setQueue_after_removeFromBitmap:
  "(setQueue d p q >>= (\<lambda>rv. (when P (removeFromBitmap d p)) >>= (\<lambda>rv. threadSet f t))) =
   (when P (removeFromBitmap d p) >>= (\<lambda>rv. (threadSet f t) >>= (\<lambda>rv. setQueue d p q)))"
  supply bind_assoc[simp add]
  apply (case_tac P, simp_all)
   prefer 2
   apply (simp add: setQueue_after)
  apply (simp add: setQueue_def when_def)
  apply (subst oblivious_modify_swap)
   apply (fastforce simp: threadSet_def getObject_def setObject_def readObject_def
                          loadObject_default_def bitmap_fun_defs gets_the_def obind_def
                          split_def projectKO_def alignCheck_assert read_magnitudeCheck_assert
                          magnitudeCheck_assert updateObject_default_def omonad_defs
                   intro: oblivious_bind split: option.splits)
  apply clarsimp
  done

crunch isFinalCapability
  for valid_objs'[wp]: valid_objs'
  (wp: crunch_wps simp: crunch_simps)

crunch cteDeleteOne
  for ksCurDomain[wp]:  "\<lambda>s. P (ksCurDomain s)"
  and tcbDomain_obj_at'[wp]: "obj_at' (\<lambda>tcb. P (tcbDomain tcb)) t'"
  (wp: crunch_wps simp: crunch_simps unless_def wp_comb: hoare_weaken_pre)

end

global_interpretation delete_one_conc_pre
  by (unfold_locales, wp)
     (wp cteDeleteOne_tcbDomain_obj_at' cteDeleteOne_typ_at' | simp)+

lemma cteDeleteOne_invs[wp]:
  "cteDeleteOne ptr \<lbrace>invs'\<rbrace>"
  apply (simp add: cteDeleteOne_def unless_def
                   split_def finaliseCapTrue_standin_simple_def)
  apply wp
     apply (rule hoare_strengthen_post)
      apply (rule hoare_vcg_conj_lift)
       apply (rule finaliseCap_True_invs')
      apply (rule hoare_vcg_conj_lift)
       apply (rule finaliseCap_replaceable[where slot=ptr])
      apply (rule hoare_vcg_conj_lift)
       apply (rule finaliseCap_cte_refs)
      apply (rule finaliseCap_equal_cap[where sl=ptr])
     apply (clarsimp simp: cte_wp_at_ctes_of)
     apply (erule disjE)
      apply simp
     apply (clarsimp dest!: isCapDs simp: capRemovable_def)
     apply (clarsimp simp: removeable'_def fun_eq_iff[where f="cte_refs' cap" for cap]
                      del: disjCI)
     apply (rule disjI2)
     apply (rule conjI)
      apply fastforce
     apply (fastforce dest!: isCapDs simp: pred_tcb_at'_def obj_at'_def ko_wp_at'_def)
    apply (wp isFinalCapability_inv getCTE_wp' hoare_weak_lift_imp
           | wp (once) isFinal[where x=ptr])+
  apply (fastforce simp: cte_wp_at_ctes_of)
  done

global_interpretation delete_one_conc_fr: delete_one_conc
  by unfold_locales wpsimp

declare cteDeleteOne_invs[wp]

lemma deletingIRQHandler_invs' [wp]:
  "\<lbrace>invs'\<rbrace> deletingIRQHandler i \<lbrace>\<lambda>_. invs'\<rbrace>"
  apply (simp add: deletingIRQHandler_def getSlotCap_def
                   getIRQSlot_def locateSlot_conv getInterruptState_def)
  apply (wp getCTE_wp')
  apply simp
  done

lemma schedContextSetInactive_invs'[wp]:
  "schedContextSetInactive scPtr \<lbrace>invs'\<rbrace>"
  apply (clarsimp simp: schedContextSetInactive_def updateSchedContext_def)
  apply (rule bind_wp_fwd_skip)
  apply (wpsimp wp: setSchedContext_invs' hoare_vcg_all_lift)
   apply (fastforce dest: invs'_ko_at_valid_sched_context' intro!: if_live_then_nonz_capE'
                    simp: ko_wp_at'_def obj_at'_def live_sc'_def
                          valid_sched_context'_def valid_sched_context_size'_def objBits_simps')
  apply (wpsimp wp: setSchedContext_invs' hoare_vcg_all_lift hoare_vcg_imp_lift' )
  apply (fastforce dest: invs'_ko_at_valid_sched_context' intro!: if_live_then_nonz_capE'
                     simp: ko_wp_at'_def obj_at'_def live_sc'_def
                           valid_sched_context'_def valid_sched_context_size'_def objBits_simps')
  done

lemma schedContextUnbindYieldFrom_invs'[wp]:
  "schedContextUnbindYieldFrom scPtr \<lbrace>invs'\<rbrace>"
  apply (clarsimp simp: schedContextUnbindYieldFrom_def)
  apply wpsimp
  done

lemma schedContextUnbindReply_invs'[wp]:
  "schedContextUnbindReply scPtr \<lbrace>invs'\<rbrace>"
  unfolding schedContextUnbindReply_def
  apply (wpsimp wp: setSchedContext_invs' updateReply_replyNext_None_invs'
                    hoare_vcg_imp_lift typ_at_lifts)
  apply (clarsimp simp: invs'_def valid_pspace'_def sym_refs_asrt_def)
  apply (frule (1) ko_at_valid_objs', clarsimp)
  apply (frule (3) sym_refs_scReplies)
  apply (intro conjI)
     apply (fastforce simp: obj_at'_def opt_map_def sym_heap_def split: option.splits)
    apply (fastforce elim: if_live_then_nonz_capE'
                     simp: ko_wp_at'_def obj_at'_def live_sc'_def)
   apply (auto simp: valid_obj'_def valid_sched_context'_def valid_sched_context_size'_def
                     objBits_simps' refillSize_def)
  done

lemma schedContextUnbindAllTCBs_invs'[wp]:
  "\<lbrace>invs' and K (scPtr \<noteq> idle_sc_ptr)\<rbrace>
   schedContextUnbindAllTCBs scPtr
   \<lbrace>\<lambda>rv. invs'\<rbrace>"
  apply (clarsimp simp: schedContextUnbindAllTCBs_def)
  by wpsimp

lemma finaliseCap_invs:
  "\<lbrace>invs' and valid_cap' cap and cte_wp_at' (\<lambda>cte. cteCap cte = cap) sl\<rbrace>
   finaliseCap cap fin flag
   \<lbrace>\<lambda>_. invs'\<rbrace>"
  apply (simp add: finaliseCap_def Let_def
             cong: if_cong split del: if_split)
  apply (rule hoare_pre)
   apply (wpsimp wp: hoare_vcg_all_lift)
  apply (case_tac cap; clarsimp simp: isCap_simps)
   apply (frule invs_valid_global', drule(1) valid_globals_cte_wpD'_idleThread)
   apply (frule valid_capAligned, drule capAligned_capUntypedPtr)
    apply clarsimp
   apply (clarsimp dest!: simp: valid_cap'_def valid_idle'_def valid_idle'_asrt_def)
  apply (subgoal_tac "ex_nonz_cap_to' (ksIdleThread s) s")
   apply (fastforce simp: invs'_def global'_no_ex_cap)
  apply (frule invs_valid_global', drule(1) valid_globals_cte_wpD'_idleSC)
  apply (frule valid_capAligned, drule capAligned_capUntypedPtr)
   apply clarsimp
  apply clarsimp
  done

lemma finaliseCap_zombie_cap[wp]:
  "finaliseCap cap fin flag \<lbrace>cte_wp_at' (\<lambda>cte. (P and isZombie) (cteCap cte)) sl\<rbrace>"
  apply (simp add: finaliseCap_def Let_def
             cong: if_cong split del: if_split)
  apply (wpsimp wp: suspend_cte_wp_at' deletingIRQHandler_cte_preserved
              simp: finaliseCap_def isCap_simps)
  done

lemma finaliseCap_zombie_cap':
  "\<lbrace>cte_wp_at' (\<lambda>cte. (P and isZombie) (cteCap cte)) sl\<rbrace>
   finaliseCap cap fin flag
   \<lbrace>\<lambda>_. cte_wp_at' (\<lambda>cte. P (cteCap cte)) sl\<rbrace>"
  apply (rule hoare_strengthen_post)
   apply (rule finaliseCap_zombie_cap)
  apply (clarsimp simp: cte_wp_at_ctes_of)
  done

lemma finaliseCap_cte_cap_wp_to[wp]:
  "finaliseCap cap fin flag \<lbrace>ex_cte_cap_wp_to' P sl\<rbrace>"
  apply (simp add: ex_cte_cap_to'_def)
  apply (rule hoare_pre, rule hoare_use_eq_irq_node' [OF finaliseCap_irq_node'])
   apply (simp add: finaliseCap_def Let_def
              cong: if_cong split del: if_split)
   apply (wpsimp wp: suspend_cte_wp_at' deletingIRQHandler_cte_preserved
                     hoare_vcg_ex_lift
               simp: finaliseCap_def isCap_simps
          | rule conjI)+
  apply fastforce
  done

global_interpretation unbindNotification: typ_at_all_props' "unbindNotification tcb"
  by typ_at_props'

context begin interpretation Arch . (*FIXME: arch-split*)

lemma finaliseCap_valid_cap[wp]:
  "\<lbrace>valid_cap' cap\<rbrace> finaliseCap cap final flag \<lbrace>\<lambda>rv. valid_cap' (fst rv)\<rbrace>"
  apply (simp add: finaliseCap_def Let_def
                   getThreadCSpaceRoot
                   RISCV64_H.finaliseCap_def
             cong: if_cong split del: if_split)
  apply wpsimp
  by (auto simp: valid_cap'_def isCap_simps capAligned_def objBits_simps shiftL_nat)

crunch "Arch.finaliseCap"
  for nosch[wp]: "\<lambda>s. P (ksSchedulerAction s)"
  (wp: crunch_wps getObject_inv simp: loadObject_default_def updateObject_default_def)

end

lemma interrupt_cap_null_or_ntfn:
  "invs s
    \<Longrightarrow> cte_wp_at (\<lambda>cp. is_ntfn_cap cp \<or> cp = cap.NullCap) (interrupt_irq_node s irq, []) s"
  apply (frule invs_valid_irq_node)
  apply (clarsimp simp: valid_irq_node_def)
  apply (drule_tac x=irq in spec)
  apply (drule cte_at_0)
  apply (clarsimp simp: cte_wp_at_caps_of_state)
  apply (drule caps_of_state_cteD)
  apply (frule if_unsafe_then_capD, clarsimp+)
  apply (clarsimp simp: ex_cte_cap_wp_to_def cte_wp_at_caps_of_state)
  apply (frule cte_refs_obj_refs_elem, erule disjE)
   apply (clarsimp | drule caps_of_state_cteD valid_global_refsD[rotated]
     | rule irq_node_global_refs[where irq=irq])+
   apply (simp add: cap_range_def)
  apply (clarsimp simp: appropriate_cte_cap_def
                 split: cap.split_asm)
  done

lemma (in delete_one) deletingIRQHandler_corres:
  "corres dc
          (einvs and simple_sched_action and current_time_bounded)
          invs'
          (deleting_irq_handler irq) (deletingIRQHandler irq)"
  apply (simp add: deleting_irq_handler_def deletingIRQHandler_def)
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF getIRQSlot_corres])
      apply simp
      apply (rule_tac P'="cte_at' (cte_map slot)" in corres_symb_exec_r_conj)
         apply (rule_tac F="isNotificationCap rv \<or> rv = capability.NullCap"
             and P="cte_wp_at (\<lambda>cp. is_ntfn_cap cp \<or> cp = cap.NullCap) slot
                 and einvs and simple_sched_action and current_time_bounded"
             and P'="invs' and cte_wp_at' (\<lambda>cte. cteCap cte = rv)
                 (cte_map slot)" in corres_req)
          apply (clarsimp simp: cte_wp_at_caps_of_state state_relation_def)
          apply (drule caps_of_state_cteD)
          apply (drule(1) pspace_relation_cte_wp_at, clarsimp+)
          apply (auto simp: cte_wp_at_ctes_of is_cap_simps isCap_simps)[1]
         apply simp
         apply (rule corres_guard_imp, rule delete_one_corres[unfolded dc_def])
          apply (auto simp: cte_wp_at_caps_of_state is_cap_simps can_fast_finalise_def)[1]
         apply (clarsimp simp: cte_wp_at_ctes_of)
        apply (wp getCTE_wp' | simp add: getSlotCap_def)+
     apply (wp | simp add: get_irq_slot_def getIRQSlot_def
                           locateSlot_conv getInterruptState_def)+
   apply (clarsimp simp: ex_cte_cap_wp_to_def interrupt_cap_null_or_ntfn)
  apply (clarsimp simp: cte_wp_at_ctes_of)
  done

context begin interpretation Arch . (*FIXME: arch-split*)

lemma arch_finaliseCap_corres:
  "\<lbrakk> final_matters' (ArchObjectCap cap') \<Longrightarrow> final = final'; acap_relation cap cap' \<rbrakk>
     \<Longrightarrow> corres (\<lambda>r r'. cap_relation (fst r) (fst r') \<and> cap_relation (snd r) (snd r'))
           (\<lambda>s. invs s \<and> valid_etcbs s
                       \<and> s \<turnstile> cap.ArchObjectCap cap
                       \<and> (final_matters (cap.ArchObjectCap cap)
                            \<longrightarrow> final = is_final_cap' (cap.ArchObjectCap cap) s)
                       \<and> cte_wp_at ((=) (cap.ArchObjectCap cap)) sl s)
           (\<lambda>s. invs' s \<and> s \<turnstile>' ArchObjectCap cap' \<and>
                 (final_matters' (ArchObjectCap cap') \<longrightarrow>
                      final' = isFinal (ArchObjectCap cap') (cte_map sl) (cteCaps_of s)))
           (arch_finalise_cap cap final) (Arch.finaliseCap cap' final')"
  apply (cases cap,
         simp_all add: arch_finalise_cap_def RISCV64_H.finaliseCap_def
                       final_matters'_def case_bool_If liftM_def[symmetric]
                       o_def dc_def[symmetric]
                split: option.split,
         safe)
    apply (rule corres_guard_imp, rule deleteASIDPool_corres[OF refl refl])
     apply (clarsimp simp: valid_cap_def mask_def)
    apply (clarsimp simp: valid_cap'_def)
   apply auto[1]
   apply (rule corres_guard_imp, rule unmapPage_corres[OF refl refl refl refl])
    apply simp
    apply (clarsimp simp: valid_cap_def valid_unmap_def)
    apply (auto simp: vmsz_aligned_def pbfs_atleast_pageBits mask_def wellformed_mapdata_def
                elim: is_aligned_weaken)[2]
  apply (rule corres_guard_imp)
    apply (rule corres_split_catch[where f=dc])
       apply (rule corres_splitEE)
          apply (rule corres_rel_imp[where r="dc \<oplus> (=)"], rule findVSpaceForASID_corres; simp)
          apply (case_tac x; simp)
         apply (simp only: whenE_def)
         apply (rule corres_if[where Q=\<top> and Q'=\<top>], simp)
          apply simp
          apply (rule deleteASID_corres; rule refl)
         apply simp
        apply (wpsimp wp: hoare_vcg_if_lift_ER hoare_drop_imps)+
      apply (rule unmapPageTable_corres; simp)
     apply (wpsimp wp: hoare_drop_imps)+
   apply (clarsimp simp: invs_psp_aligned invs_distinct invs_vspace_objs invs_valid_asid_table)
   apply (clarsimp simp: cte_wp_at_caps_of_state)
   apply (drule (1) caps_of_state_valid)
   apply (simp add: valid_cap_def wellformed_mapdata_def)
  apply (simp add: invs_no_0_obj')
  done

lemma unbindNotification_corres:
  "corres dc
      (invs and tcb_at t)
      invs'
      (unbind_notification t)
      (unbindNotification t)"
  supply option.case_cong_weak[cong]
  apply (simp add: unbind_notification_def unbindNotification_def)
  apply (rule corres_cross[where Q' = "tcb_at' t", OF tcb_at'_cross_rel])
   apply (simp add: invs_psp_aligned invs_distinct)
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF getBoundNotification_corres])
      apply (simp add: maybeM_def)
      apply (rule corres_option_split)
        apply simp
       apply (rule corres_return_trivial)
      apply (simp add: update_sk_obj_ref_def bind_assoc)
      apply (rule corres_split[OF getNotification_corres])
        apply (rule corres_split[OF setNotification_corres])
           apply (clarsimp simp: ntfn_relation_def split: Structures_A.ntfn.splits)
          apply (rule setBoundNotification_corres)
         apply (wpsimp wp: gbn_wp' gbn_wp get_ntfn_ko' simp: obj_at_def split: option.split)+
   apply (frule invs_valid_objs)
   apply (clarsimp simp: is_tcb)
   apply (frule_tac thread=t and y=tcb in valid_tcb_objs)
    apply (simp add: get_tcb_rev)
   apply (clarsimp simp: valid_tcb_def cteSizeBits_def invs_def valid_state_def valid_pspace_def)
   apply (metis obj_at_simps(1) valid_bound_obj_Some)
  apply (clarsimp dest!: obj_at_valid_objs' invs_valid_objs'
                   simp: valid_obj'_def valid_tcb'_def valid_bound_ntfn'_def pred_tcb_at'_def
                  split: option.splits)
  done

lemma unbindMaybeNotification_corres:
  "corres dc
      (invs and ntfn_at ntfnptr)
      invs'
      (unbind_maybe_notification ntfnptr)
      (unbindMaybeNotification ntfnptr)"
  apply (simp add: unbind_maybe_notification_def unbindMaybeNotification_def)
  apply (rule corres_cross[where Q' = "ntfn_at' ntfnptr", OF ntfn_at'_cross_rel])
   apply (simp add: invs_psp_aligned invs_distinct)
  apply (rule corres_guard_imp)
    apply (clarsimp simp: maybeM_def get_sk_obj_ref_def)
    apply (rule corres_split[OF getNotification_corres])
      apply (rename_tac ntfnA ntfnH)
      apply (rule corres_option_split)
        apply (simp add: ntfn_relation_def)
       apply (rule corres_return_trivial)
      apply (rename_tac tcbPtr)
      apply (simp add: bind_assoc)
      apply (rule corres_split)
         apply (simp add: update_sk_obj_ref_def)
         apply (rule_tac P="ko_at (Notification ntfnA) ntfnptr" in corres_symb_exec_l)
            apply (rename_tac ntfnA')
            apply (rule_tac F="ntfnA = ntfnA'" in corres_gen_asm)
            apply (rule setNotification_corres)
            apply (clarsimp simp: ntfn_relation_def split: Structures_A.ntfn.splits)
           apply (wpsimp simp: obj_at_def is_ntfn wp: get_simple_ko_wp)+
        apply (rule setBoundNotification_corres)
       apply (wpsimp simp: obj_at_def  wp: get_simple_ko_wp getNotification_wp)+
   apply (frule invs_valid_objs)
   apply (erule (1) pspace_valid_objsE)
   apply (fastforce simp: valid_obj_def valid_ntfn_def obj_at_def split: option.splits)
  apply clarsimp
  apply (frule invs_valid_objs')
  apply (frule (1) ko_at_valid_objs'_pre)
  apply (clarsimp simp: valid_obj'_def valid_ntfn'_def split: option.splits)
  done

lemma schedContextUnbindNtfn_corres:
  "corres dc
     (invs and sc_at sc)
     invs'
     (sched_context_unbind_ntfn sc)
     (schedContextUnbindNtfn sc)"
  apply (simp add: sched_context_unbind_ntfn_def schedContextUnbindNtfn_def)
  apply (clarsimp simp: maybeM_def get_sk_obj_ref_def liftM_def)
  apply (rule corres_cross[where Q' = "sc_at' sc", OF sc_at'_cross_rel])
   apply (simp add: invs_psp_aligned invs_distinct)
  apply add_sym_refs
  apply (rule corres_stateAssert_implied[where P'=\<top>, simplified])
   apply (simp add: get_sc_obj_ref_def)
   apply (rule corres_guard_imp)
     apply (rule corres_split[OF get_sc_corres])
       apply (rule corres_option_split)
         apply (simp add: sc_relation_def)
        apply (rule corres_return_trivial)
       apply (simp add: update_sk_obj_ref_def bind_assoc)
       apply (rule corres_split[OF getNotification_corres])
         apply (rule corres_split[OF setNotification_corres])
            apply (clarsimp simp: ntfn_relation_def split: Structures_A.ntfn.splits)
           apply (rule_tac f'="scNtfn_update (\<lambda>_. None)"
                    in update_sc_no_reply_stack_update_ko_at'_corres)
              apply (clarsimp simp: sc_relation_def objBits_def objBitsKO_def refillSize_def)+
          apply wpsimp+
    apply (frule invs_valid_objs)
    apply (frule (1) valid_objs_ko_at)
    apply (clarsimp simp: invs_psp_aligned valid_obj_def valid_sched_context_def
                   split: option.splits)
   apply (clarsimp split: option.splits)
   apply (frule (1) scNtfn_sym_refsD[OF ko_at_obj_at', simplified])
     apply clarsimp+
  apply normalise_obj_at'
  apply (clarsimp simp: sym_refs_asrt_def)
  done

lemma sched_context_maybe_unbind_ntfn_corres:
  "corres dc
     (invs and ntfn_at ntfn_ptr)
     invs'
     (sched_context_maybe_unbind_ntfn ntfn_ptr)
     (schedContextMaybeUnbindNtfn ntfn_ptr)"
  apply (clarsimp simp: sched_context_maybe_unbind_ntfn_def schedContextMaybeUnbindNtfn_def)
  apply (clarsimp simp: maybeM_def get_sk_obj_ref_def liftM_def)
  apply (rule corres_cross[where Q' = "ntfn_at' ntfn_ptr", OF ntfn_at'_cross_rel])
   apply (simp add: invs_psp_aligned invs_distinct)
  apply add_sym_refs
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF getNotification_corres])
      apply (rename_tac ntfnA ntfnH)
      apply (rule corres_option_split)
        apply (simp add: ntfn_relation_def)
       apply (rule corres_return_trivial)
      apply (rename_tac scAPtr)
      apply (clarsimp simp: schedContextUnbindNtfn_def update_sk_obj_ref_def bind_assoc)
      apply (rule corres_stateAssert_implied[where P'=\<top>, simplified])
       apply (rule_tac P="invs and ko_at (Notification ntfnA) ntfn_ptr"
                and P'="invs' and ko_at' ntfnH ntfn_ptr and (\<lambda>s. sym_refs (state_refs_of' s))"
                and Q'1=\<top>
                in corres_symb_exec_r'[THEN corres_guard_imp])
            apply (rule_tac F="scNtfn rv = Some ntfn_ptr" in corres_gen_asm2)
            apply clarsimp
            apply (rule corres_split[OF getNotification_corres])
              apply (rule corres_split[OF setNotification_corres])
                 apply (clarsimp simp: ntfn_relation_def split: Structures_A.ntfn.splits)
                apply (rule_tac f'="scNtfn_update (\<lambda>_. None)"
                         in update_sc_no_reply_stack_update_ko_at'_corres)
                   apply (clarsimp simp: sc_relation_def objBits_def objBitsKO_def refillSize_def)+
               apply wpsimp+
        apply (frule invs_valid_objs)
        apply (frule (1) valid_objs_ko_at)
        apply (clarsimp simp: invs_psp_aligned valid_obj_def valid_ntfn_def obj_at_def is_ntfn_def)
       apply (clarsimp simp: valid_ntfn'_def ntfn_relation_def split: option.splits)
       apply (drule_tac s="Some scAPtr" in sym)
       apply (clarsimp simp: valid_ntfn'_def ntfn_relation_def sym_refs_asrt_def)
       apply (frule (1) ntfnSc_sym_refsD[OF ko_at_obj_at', simplified])
        apply clarsimp+
       apply normalise_obj_at'
      apply (clarsimp simp: sym_refs_asrt_def)
     apply (wpsimp wp: get_simple_ko_wp getNotification_wp split: option.splits)+
  done

lemma replyClear_corres:
  "corres dc
          (invs and valid_ready_qs and st_tcb_at is_reply_state tp
           and active_scs_valid and weak_valid_sched_action and valid_release_q
           and ready_or_release)
          (invs' and st_tcb_at' (\<lambda>st. replyObject st = Some rptr) tp)
          (do
             state \<leftarrow> get_thread_state tp;
             case state of
                 Structures_A.thread_state.BlockedOnReply r \<Rightarrow> reply_remove tp r
               | _ \<Rightarrow> cancel_ipc tp
           od)
          (replyClear rptr tp)"
  apply (clarsimp simp: replyClear_def)
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF getThreadState_corres])
      apply (rename_tac st st')
      apply (rule_tac R="is_blocked_on_receive st" in corres_cases_lhs;
             clarsimp simp: thread_state_relation_def is_blocked_thread_state_defs)
       apply (rule cancel_ipc_corres)
      apply (rule_tac R="is_blocked_on_reply st" in corres_cases_lhs;
             clarsimp simp: is_blocked_thread_state_defs)
       apply (wpfix add: Structures_H.thread_state.sel)
       apply (rule corres_guard_imp)
         apply (rule_tac st="Structures_A.BlockedOnReply reply"
                     and st'="BlockedOnReply (Some reply)"
               in replyRemove_corres)
          apply simp
         apply simp
        apply simp
       apply simp
      apply (rule corres_False'[where P'=\<top>])
     apply (wpsimp wp: gts_wp gts_wp')+
   apply (clarsimp simp: pred_tcb_at_def obj_at_def is_obj_defs invs_def valid_pspace_def valid_state_def)
  apply (clarsimp simp: pred_tcb_at'_def obj_at'_def invs'_def valid_pspace'_def)
  done

lemma fast_finaliseCap_corres:
  "\<lbrakk> final_matters' cap' \<longrightarrow> final = final'; cap_relation cap cap';
     can_fast_finalise cap \<rbrakk>
   \<Longrightarrow> corres dc
           (\<lambda>s. invs s \<and> valid_sched s \<and> s \<turnstile> cap \<and> current_time_bounded s
                       \<and> cte_wp_at ((=) cap) sl s)
           (\<lambda>s. invs' s \<and> s \<turnstile>' cap')
           (fast_finalise cap final)
           (finaliseCap cap' final' True)"
  apply add_sch_act_wf
  apply (cases cap, simp_all add: finaliseCap_def isCap_simps final_matters'_def
                                  corres_liftM2_simp[unfolded liftM_def]
                                  o_def dc_def[symmetric] when_def
                                  can_fast_finalise_def capRemovable_def
                       split del: if_split cong: if_cong)
    (* EndpointCap *)
    apply clarsimp
    apply (rule corres_stateAssert_assume; (simp add: sch_act_wf_asrt_def)?)
    apply (rule corres_guard_imp)
      apply (rule cancelAllIPC_corres)
     apply (simp add: valid_cap_def)
    apply (simp add: valid_cap'_def)
   (* NotificationCap *)
   apply clarsimp
   apply (rule corres_stateAssert_assume; (simp add: sch_act_wf_asrt_def)?)
   apply (rule corres_guard_imp)
     apply (rule corres_split[OF sched_context_maybe_unbind_ntfn_corres])
       apply (rule corres_split[OF unbindMaybeNotification_corres])
         apply (rule cancelAllSignals_corres)
        apply (wpsimp wp: unbind_maybe_notification_invs abs_typ_at_lifts typ_at_lifts)+
    apply (clarsimp simp: valid_cap_def)
   apply (clarsimp simp: valid_cap'_def)
  (* ReplyCap *)
  apply clarsimp
  apply (rename_tac rptr rs)
  apply (add_sym_refs, add_valid_replies rptr simp: valid_cap_def, add_sch_act_wf)
  apply (rule corres_stateAssert_assume; (simp add: sym_refs_asrt_def)?)
  apply (rule corres_stateAssert_assume; simp?)
  apply (rule corres_stateAssert_assume; (simp add: sch_act_wf_asrt_def)?)
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF getReply_TCB_corres])
      apply (simp split del: if_split)
      apply (rule_tac R="tptrOpt = None" in corres_cases';
             clarsimp simp del: corres_return)
       apply (rule corres_return_trivial)
      apply wpfix
      apply (rule replyClear_corres)
     apply (wpsimp wp: get_simple_ko_wp)+
   apply (clarsimp simp: valid_cap_def valid_sched_valid_ready_qs)
   apply (drule reply_tcb_state_refs;
          fastforce simp: pred_tcb_at_def obj_at_def is_blocked_thread_state_defs
                    elim: reply_object.elims)
  apply (clarsimp simp: valid_cap'_def)
  apply (rule pred_tcb'_weakenE, erule sym_ref_replyTCB_Receive_or_Reply; fastforce)
  done

lemma finaliseCap_true_removable[wp]:
  "\<lbrace>\<top>\<rbrace>
   finaliseCap cap final True
   \<lbrace>\<lambda>rv s. capRemovable (fst rv) (cte_map slot) \<and> snd rv = capability.NullCap\<rbrace>"
  by (cases cap; wpsimp simp: finaliseCap_def isCap_simps capRemovable_def)

lemma cap_delete_one_corres:
  "corres dc
        (einvs and simple_sched_action and cte_wp_at can_fast_finalise slot
         and current_time_bounded)
        (invs' and cte_at' (cte_map slot))
        (cap_delete_one slot) (cteDeleteOne (cte_map slot))"
  apply (simp add: cap_delete_one_def cteDeleteOne_def'
                   unless_def when_def)
  apply (rule corres_cross[OF sch_act_simple_cross_rel], clarsimp)
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF get_cap_corres])
      apply (rule_tac F="can_fast_finalise cap" in corres_gen_asm)
      apply (rule corres_if)
        apply fastforce
       apply (rule corres_split[OF isFinalCapability_corres[where ptr=slot]])
         apply (rule corres_split[OF fast_finaliseCap_corres[where sl=slot]])
              apply simp+
           apply clarsimp
           apply wpfix
           apply (rule corres_assert_assume_r)
           apply (rule emptySlot_corres)
           apply (wpsimp wp: hoare_drop_imps fast_finalise_invs fast_finalise_valid_sched)+
       apply (wp isFinalCapability_inv)
      apply (rule corres_trivial, simp)
     apply (wp get_cap_wp getCTE_wp)+
   apply (fastforce simp: cte_wp_at_caps_of_state can_fast_finalise_Null
                simp del: split_paired_Ex
                   elim!: caps_of_state_valid_cap)
  apply (fastforce simp: cte_wp_at_ctes_of)
  done

end
(* FIXME: strengthen locale instead *)

global_interpretation delete_one
  apply unfold_locales
  apply (rule corres_guard_imp)
    apply (rule cap_delete_one_corres)
   apply auto
  done

lemma schedContextUnbindTCB_corres:
  "corres dc (invs and valid_sched and sc_tcb_sc_at bound sc_ptr)
             (invs' and obj_at' (\<lambda>sc. bound (scTCB sc)) sc_ptr)
          (sched_context_unbind_tcb sc_ptr) (schedContextUnbindTCB sc_ptr)"
  apply (clarsimp simp: sched_context_unbind_tcb_def schedContextUnbindTCB_def
                        sym_refs_asrt_def valid_idle'_asrt_def cur_tcb'_asrt_def)
  apply add_sym_refs
  apply add_valid_idle'
  apply add_cur_tcb'
  apply (rule corres_stateAssert_implied[where P'=\<top>, simplified])
   apply (rule corres_stateAssert_add_assertion[rotated], simp)+
  apply (rule corres_guard_imp)
     apply (rule corres_split[OF get_sc_corres])
       apply (rename_tac sc sc')
       apply (rule corres_assert_opt_assume_l)
       apply (rule corres_assert_assume_r)
       apply (prop_tac "scTCB sc' = sc_tcb sc"; clarsimp)
        apply (clarsimp simp: sc_relation_def)
       apply (rule corres_split[OF getCurThread_corres])
         apply (rule corres_split[OF corres_when], clarsimp simp: sc_relation_def)
            apply (rule rescheduleRequired_corres)
           apply (rule corres_split[OF tcbSchedDequeue_corres], simp)
             apply (rule corres_split[OF tcbReleaseRemove_corres])
             apply (clarsimp simp: sc_relation_def)
               apply (rule corres_split[OF set_tcb_obj_ref_corres];
                      clarsimp simp: tcb_relation_def inQ_def)
                 apply (rule_tac sc'=sc' in update_sc_no_reply_stack_update_ko_at'_corres)
                    apply (clarsimp simp: sc_relation_def objBits_def objBitsKO_def refillSize_def)+
                apply wpsimp+
       apply (case_tac sc'; clarsimp)
       apply (wpfix add: sched_context.sel)
       apply wpsimp+
    apply (frule invs_valid_objs)
    apply (frule valid_sched_valid_release_q)
    apply (fastforce dest: valid_sched_valid_ready_qs
                     simp: sc_at_pred_n_def obj_at_def is_obj_defs valid_obj_def
                           valid_sched_context_def)
   apply normalise_obj_at'
   apply (fastforce simp: valid_obj'_def valid_sched_context'_def
                   dest!: ko_at_valid_objs')
  apply clarsimp
  done

lemma unbindFromSC_corres:
  "corres dc (einvs and tcb_at t and K (t \<noteq> idle_thread_ptr)) (invs' and tcb_at' t)
          (unbind_from_sc t) (unbindFromSC t)"
  apply (clarsimp simp: unbind_from_sc_def unbindFromSC_def maybeM_when)
  apply (rule corres_gen_asm)
  apply add_sym_refs
  apply (rule corres_stateAssert_implied[where P'=\<top>, simplified])
   apply (rule corres_guard_imp)
     apply (rule corres_split[OF get_tcb_obj_ref_corres[where r="(=)"]])
        apply (clarsimp simp: tcb_relation_def)
       apply (rename_tac sc_ptr_opt sc_ptr_opt')
       apply clarsimp
       apply (rule_tac R="bound sc_ptr_opt'" in corres_cases'; clarsimp)
       apply wpfix
       apply (rule corres_split[OF schedContextUnbindTCB_corres])
         apply (rule corres_split[OF get_sc_corres])
           apply (rule corres_when2; clarsimp simp: sc_relation_def)
           apply (case_tac rv, case_tac rv', simp)
           apply (wpfix add: Structures_A.sched_context.select_convs sched_context.sel)
           apply (rule schedContextCompleteYieldTo_corres)
          apply (wpsimp wp: abs_typ_at_lifts)+
        apply (rule_tac Q'="\<lambda>_. invs" in hoare_post_imp)
         apply (auto simp: valid_obj_def valid_sched_context_def
                    dest!: invs_valid_objs valid_objs_ko_at)[1]
        apply wpsimp
       apply (rule_tac Q'="\<lambda>_. sc_at' y and invs'" in hoare_post_imp)
        apply (fastforce simp: valid_obj'_def valid_sched_context'_def
                        dest!: ko_at_valid_objs')
       apply (wpsimp wp: typ_at_lifts get_tcb_obj_ref_wp threadGet_wp)+
    apply (frule invs_psp_aligned, frule invs_distinct)
    apply clarsimp
    apply (frule invs_valid_objs, frule invs_sym_refs, frule invs_valid_global_refs)
    apply (frule sym_ref_tcb_sc; (fastforce simp: obj_at_def is_tcb_def)?)
    apply (frule (1) valid_objs_ko_at)
    apply (subgoal_tac "ex_nonz_cap_to y s")
     apply (fastforce dest!: idle_sc_no_ex_cap
                       simp: obj_at_def sc_at_pred_n_def valid_obj_def valid_tcb_def)
    apply (fastforce elim!: if_live_then_nonz_cap_invs simp: live_def live_sc_def)
   apply clarsimp
   apply (drule obj_at_ko_at', clarsimp)
   apply (frule sym_refs_tcbSchedContext; assumption?)
   apply (subgoal_tac "ex_nonz_cap_to' y s")
    apply (fastforce simp: invs'_def obj_at'_def global'_sc_no_ex_cap)
   apply (fastforce intro!: if_live_then_nonz_capE'
                      simp: obj_at'_def ko_wp_at'_def live_sc'_def)
  apply (clarsimp simp: sym_refs_asrt_def)
  done

lemma schedContextUnbindAllTCBs_corres:
  "corres dc (einvs and sc_at scPtr and K (scPtr \<noteq> idle_sc_ptr)) (invs' and sc_at' scPtr)
          (sched_context_unbind_all_tcbs scPtr) (schedContextUnbindAllTCBs scPtr)"
  apply (clarsimp simp: sched_context_unbind_all_tcbs_def schedContextUnbindAllTCBs_def)
  apply (rule corres_gen_asm, clarsimp)
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF get_sc_corres])
      apply (rule corres_when)
       apply (clarsimp simp: sc_relation_def)
      apply (rule schedContextUnbindTCB_corres)
     apply wpsimp+
   apply (clarsimp simp: sc_at_pred_n_def obj_at_def)
  apply (clarsimp simp: obj_at'_def)
  done

lemma replyNext_update_corres_empty:
  "corres dc (reply_at rptr) (reply_at' rptr)
   (set_reply_obj_ref reply_sc_update rptr None)
   (updateReply rptr (\<lambda>reply. replyNext_update (\<lambda>_. None) reply))"
  unfolding update_sk_obj_ref_def updateReply_def
  apply (rule corres_guard_imp)
    apply (rule corres_split[OF get_reply_corres set_reply_corres])
      apply (clarsimp simp: reply_relation_def)
     apply wpsimp+
  apply (clarsimp simp: obj_at'_def replyPrev_same_def)
  done

lemma schedContextUnbindReply_corres:
  "corres dc (einvs and sc_at scPtr and K (scPtr \<noteq> idle_sc_ptr)) (invs' and sc_at' scPtr)
             (sched_context_unbind_reply scPtr) (schedContextUnbindReply scPtr)"
  apply (clarsimp simp: sched_context_unbind_reply_def schedContextUnbindReply_def
                        liftM_def unless_def)
  apply add_sym_refs
  apply (rule corres_stateAssert_implied[where P'=\<top>, simplified])
   apply (rule corres_guard_imp)
     apply (rule corres_split[OF get_sc_corres, where R'="\<lambda>sc. ko_at' sc scPtr"])
       apply (rename_tac sc sc')
       apply (rule_tac Q'="ko_at' sc' scPtr
                and K (scReply sc' = hd_opt (sc_replies sc))
                and (\<lambda>s. scReply sc' \<noteq> None \<longrightarrow> reply_at' (the (scReply sc')) s)
                and (\<lambda>s. heap_ls (replyPrevs_of s) (scReply sc') (sc_replies sc))"
              and Q="sc_at scPtr
                and pspace_aligned and pspace_distinct and valid_objs
                and (\<lambda>s. \<exists>n. ko_at (Structures_A.SchedContext sc n) scPtr s)"
              in stronger_corres_guard_imp)
         apply (rule corres_guard_imp)
           apply (rule_tac F="(sc_replies sc \<noteq> []) = (\<exists>y. scReply sc' = Some y)" in corres_gen_asm2)
           apply (rule corres_when)
            apply clarsimp
           apply (rule_tac F="scReply sc' = Some (hd (sc_replies sc))" in corres_gen_asm2)
           apply clarsimp
           apply (rule corres_split[OF replyNext_update_corres_empty])
             apply (rule update_sc_reply_stack_update_ko_at'_corres)
            apply wpsimp+
          apply (clarsimp simp: obj_at_def)
          apply (frule (1) valid_sched_context_objsI)
          apply (clarsimp simp: valid_sched_context_def list_all_def obj_at_def)
         apply clarsimp
         apply (case_tac "sc_replies sc"; simp)
        apply assumption
       apply (clarsimp simp: obj_at_def)
       apply (frule state_relation_sc_replies_relation)
       apply (subgoal_tac "scReply sc' = hd_opt (sc_replies sc)")
        apply (intro conjI)
          apply clarsimp
         apply clarsimp
         apply (erule (1) reply_at_cross[rotated])
          apply (frule (1) valid_sched_context_objsI)
          apply (clarsimp simp: valid_sched_context_def list_all_def obj_at_def)
         apply fastforce
        apply (erule (1) sc_replies_relation_prevs_list)
        apply (clarsimp simp: obj_at'_real_def ko_wp_at'_def projectKO_sc)
       apply (frule state_relation_sc_replies_relation)
       apply (frule sc_replies_relation_scReplies_of[symmetric])
         apply (fastforce simp: obj_at_def is_sc_obj_def obj_at'_def)
        apply (fastforce simp: obj_at'_def opt_map_def)
       apply (fastforce simp: obj_at'_real_def opt_map_def ko_wp_at'_def sc_replies_of_scs_def
                              map_project_def scs_of_kh_def)
      apply wpsimp+
    apply (fastforce simp: sym_refs_asrt_def)+
  done

lemma schedContextUnbindYieldFrom_corres:
  "corres dc (einvs and sc_at scPtr and K (scPtr \<noteq> idle_sc_ptr)) (invs' and sc_at' scPtr)
          (sched_context_unbind_yield_from scPtr) (schedContextUnbindYieldFrom scPtr)"
  apply (clarsimp simp: sched_context_unbind_yield_from_def schedContextUnbindYieldFrom_def
                        maybeM_when)
  apply add_sym_refs
  apply (rule corres_stateAssert_implied[where P'=\<top>, simplified])
   apply (rule corres_guard_imp)
     apply (rule corres_split[OF get_sc_corres])
       apply (rename_tac sc sc')
       apply (case_tac sc')
       apply (clarsimp simp: sc_relation_def)
       apply (wpfix add: sched_context.sel)
       apply (rule corres_when)
        apply (clarsimp simp: sc_relation_def)
       apply (rule schedContextCompleteYieldTo_corres)
      apply wpsimp+
    apply (fastforce dest!: invs_valid_objs valid_objs_ko_at
                      simp: valid_obj_def valid_sched_context_def)
   apply (fastforce dest!: sc_ko_at_valid_objs_valid_sc'
                     simp: valid_obj'_def valid_sched_context'_def)
  apply (clarsimp simp: sym_refs_asrt_def)
  done

lemma schedContextSetInactive_corres:
  "corres dc (\<lambda>s. sc_at scPtr s) (sc_at' scPtr)
     (sched_context_set_inactive scPtr) (schedContextSetInactive scPtr)"
  apply (clarsimp simp: sched_context_set_inactive_def schedContextSetInactive_def)
  apply (rule corres_guard_imp)

    \<comment> \<open>collect the update of the sc_refills, sc_refill_max, and the sc_budget fields\<close>
    apply (subst bind_assoc[symmetric])
    apply (subst bind_assoc[symmetric])
    apply (subst bind_dummy_ret_val, subst update_sched_context_decompose[symmetric])
    apply (subst bind_dummy_ret_val, subst update_sched_context_decompose[symmetric])

    apply (rule corres_split)
       apply (rule updateSchedContext_no_stack_update_corres)
          apply (clarsimp simp: sc_relation_def refills_map_def)
         apply (fastforce dest: state_relation_sc_replies_relation sc_replies_relation_prevs_list
                          simp: sc_relation_def opt_map_def obj_at_simps is_sc_obj_def
                         split: Structures_A.kernel_object.splits)
        apply (clarsimp simp: objBits_simps)+
      apply (rule updateSchedContext_no_stack_update_corres)
         apply (clarsimp simp: sc_relation_def)
        apply (fastforce dest: state_relation_sc_replies_relation sc_replies_relation_prevs_list
                         simp: sc_relation_def opt_map_def obj_at_simps is_sc_obj_def
                        split: Structures_A.kernel_object.splits)
       apply (clarsimp simp: objBits_simps)
      apply (wpsimp wp: get_sched_context_wp getSchedContext_wp)+
  done

lemma can_fast_finalise_finalise_cap:
  "can_fast_finalise cap
   \<Longrightarrow> finalise_cap cap final
         = do fast_finalise cap final; return (cap.NullCap, cap.NullCap) od"
  by (cases cap; simp add: can_fast_finalise_def liftM_def)

lemma can_fast_finalise_finaliseCap:
  "is_ReplyCap cap \<or> is_EndpointCap cap \<or> is_NotificationCap cap \<or> cap = NullCap
   \<Longrightarrow> finaliseCap cap final flag
         = do finaliseCap cap final True; return (NullCap, NullCap) od"
  by (cases cap; simp add: finaliseCap_def isCap_simps)

context begin interpretation Arch . (*FIXME: arch-split*)

lemma finaliseCap_corres:
  "\<lbrakk> final_matters' cap' \<Longrightarrow> final = final'; cap_relation cap cap';
          flag \<longrightarrow> can_fast_finalise cap \<rbrakk>
     \<Longrightarrow> corres (\<lambda>x y. cap_relation (fst x) (fst y) \<and> cap_relation (snd x) (snd y))
           (\<lambda>s. einvs s \<and> s \<turnstile> cap \<and> (final_matters cap \<longrightarrow> final = is_final_cap' cap s)
                \<and> cte_wp_at ((=) cap) sl s \<and> simple_sched_action s
                \<and> current_time_bounded s)
           (\<lambda>s. invs' s \<and> s \<turnstile>' cap'
                   \<and> (final_matters' cap' \<longrightarrow>
                        final' = isFinal cap' (cte_map sl) (cteCaps_of s)))
           (finalise_cap cap final) (finaliseCap cap' final' flag)"
  apply (case_tac "can_fast_finalise cap")
   apply (simp add: can_fast_finalise_finalise_cap)
   apply (subst can_fast_finalise_finaliseCap,
          clarsimp simp: can_fast_finalise_def split: cap.splits)
   apply (rule corres_guard_imp)
     apply (rule corres_split[OF fast_finaliseCap_corres[where sl=sl]]; assumption?)
        apply simp
       apply (simp only: K_bind_def)
       apply (rule corres_returnTT)
       apply wpsimp+
  apply (cases cap, simp_all add: finaliseCap_def isCap_simps
                                  corres_liftM2_simp[unfolded liftM_def]
                                  o_def dc_def[symmetric] when_def
                                  can_fast_finalise_def
                       split del: if_split cong: if_cong)
       (* CNodeCap *)
       apply (fastforce simp: final_matters'_def shiftL_nat zbits_map_def)
      (* ThreadCap *)
      apply add_valid_idle'
      apply (rename_tac tptr)
      apply (clarsimp simp: final_matters'_def getThreadCSpaceRoot
                            liftM_def[symmetric] o_def zbits_map_def)
      apply (rule corres_stateAssert_add_assertion[rotated])
       apply (clarsimp simp: valid_idle'_asrt_def)
      apply (rule_tac P="K (tptr \<noteq> idle_thread_ptr)" and P'="K (tptr \<noteq> idle_thread_ptr)"
             in corres_add_guard)
       apply clarsimp
       apply (frule(1) valid_global_refsD[OF invs_valid_global_refs _ idle_global])
       apply (clarsimp dest!: invs_valid_idle simp: valid_idle_def cap_range_def)
      apply (rule corres_guard_imp)
        apply (rule corres_split[OF unbindNotification_corres])
          apply (rule corres_split[OF unbindFromSC_corres])
            apply (rule corres_split[OF suspend_corres])
              apply (clarsimp simp: liftM_def[symmetric] o_def dc_def[symmetric] zbits_map_def)
              apply (rule prepareThreadDelete_corres)
             apply (wp unbind_notification_invs unbind_from_sc_valid_sched)+
       apply (clarsimp simp: valid_cap_def)
      apply (clarsimp simp: valid_cap'_def)
     (* SchedContextCap *)
     apply (rename_tac scptr n)
     apply (clarsimp simp: final_matters'_def liftM_def[symmetric]
                           o_def dc_def[symmetric])
     apply (rule_tac P="K (scptr \<noteq> idle_sc_ptr)" and P'="K (scptr \<noteq> idle_sc_ptr)"
            in corres_add_guard)
      apply clarsimp
      apply (frule(1) valid_global_refsD[OF invs_valid_global_refs _ idle_sc_global])
      apply (clarsimp dest!: invs_valid_idle simp: valid_idle_def cap_range_def)
     apply (rule corres_guard_imp)
       apply (rule corres_split[OF schedContextUnbindAllTCBs_corres])
         apply (rule corres_split[OF schedContextUnbindNtfn_corres])
           apply (rule corres_split[OF schedContextUnbindReply_corres])
             apply (rule corres_split[OF schedContextUnbindYieldFrom_corres])
               apply (clarsimp simp: o_def dc_def[symmetric])
               apply (rule schedContextSetInactive_corres)
              apply (wpsimp wp: abs_typ_at_lifts typ_at_lifts)+
      apply (clarsimp simp: valid_cap_def)
     apply (clarsimp simp: valid_cap'_def sc_at'_n_sc_at')
    (* IRQHandlerCap *)
    apply (clarsimp simp: final_matters'_def liftM_def[symmetric]
                          o_def dc_def[symmetric])
    apply (rule corres_guard_imp)
      apply (rule deletingIRQHandler_corres)
     apply simp
    apply simp
   (* ZombieCap *)
   apply (clarsimp simp: final_matters'_def)
   apply (rule_tac F="False" in corres_req)
    apply clarsimp
    apply (frule zombies_finalD, (clarsimp simp: is_cap_simps)+)
    apply (clarsimp simp: cte_wp_at_caps_of_state)
   apply simp
  (* ArchObjectCap *)
  apply (clarsimp split del: if_split simp: o_def)
  apply (rule corres_guard_imp [OF arch_finaliseCap_corres], (fastforce simp: valid_sched_def)+)[1]
  done

lemma threadSet_ct_idle_or_in_cur_domain':
  "\<lbrace>ct_idle_or_in_cur_domain'
    and (\<lambda>s. \<forall>tcb. tcbDomain tcb = ksCurDomain s \<longrightarrow> tcbDomain (F tcb) = ksCurDomain s)\<rbrace>
   threadSet F t
   \<lbrace>\<lambda>_. ct_idle_or_in_cur_domain'\<rbrace>"
  apply (simp add: ct_idle_or_in_cur_domain'_def tcb_in_cur_domain'_def)
  apply (wp hoare_vcg_disj_lift hoare_vcg_imp_lift)
    apply wps
    apply wp
   apply wps
   apply wp
  apply (auto simp: obj_at'_def)
  done

context begin interpretation Arch . (*FIXME: arch-split*)

lemmas final_matters'_simps = final_matters'_def [split_simps capability.split arch_capability.split]

lemma sbn_ct_in_state'[wp]:
  "\<lbrace>ct_in_state' P\<rbrace> setBoundNotification ntfn t \<lbrace>\<lambda>_. ct_in_state' P\<rbrace>"
  apply (simp add: ct_in_state'_def)
  apply (rule hoare_pre)
   apply (wps setBoundNotification.ct)
  apply wpsimp+
  done

lemma set_ntfn_ct_in_state'[wp]:
  "\<lbrace>ct_in_state' P\<rbrace> setNotification a ntfn \<lbrace>\<lambda>_. ct_in_state' P\<rbrace>"
  apply (simp add: ct_in_state'_def)
  apply (wp_pre, wps, wp, clarsimp)
  done

lemma unbindMaybeNotification_ct_in_state'[wp]:
  "\<lbrace>ct_in_state' P\<rbrace> unbindMaybeNotification t \<lbrace>\<lambda>_. ct_in_state' P\<rbrace>"
  apply (simp add: unbindMaybeNotification_def)
  apply (wp | wpc | simp)+
  done

lemma setNotification_sch_act_sane:
  "\<lbrace>sch_act_sane\<rbrace> setNotification a ntfn \<lbrace>\<lambda>_. sch_act_sane\<rbrace>"
  by (wp sch_act_sane_lift)

context
notes option.case_cong_weak[cong]
begin
crunch unbindNotification, unbindMaybeNotification
  for sch_act_sane[wp]: "sch_act_sane"
end

end

end

end
