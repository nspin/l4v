(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

theory ArchDetSchedAux_AI
imports DetSchedAux_AI
begin


context Arch begin global_naming ARM

named_theorems DetSchedAux_AI_assms

lemmas arch_machine_ops_valid_sched_pred[wp] =
  arch_machine_ops_last_machine_time[THEN dmo_valid_sched_pred]
  arch_machine_ops_last_machine_time[THEN dmo_valid_sched_pred']

lemma set_pd_valid_sched_pred[wp]:
  "set_pd ptr pd \<lbrace>valid_sched_pred_strong P\<rbrace>"
  apply (wpsimp simp: set_pd_def wp: set_object_wp_strong get_object_wp)
  by (auto simp: obj_at_kh_kheap_simps vs_all_heap_simps a_type_def fun_upd_def
           split:  kernel_object.splits if_splits)

lemma set_pt_valid_sched_pred[wp]:
  "set_pt ptr pt \<lbrace>valid_sched_pred_strong P\<rbrace>"
  apply (wpsimp simp: set_pt_def wp: set_object_wp_strong get_object_wp)
  by (auto simp: obj_at_kh_kheap_simps vs_all_heap_simps a_type_def fun_upd_def
           split:  kernel_object.splits if_splits)

lemma set_asid_pool_bound_sc_obj_tcb_at[wp]:
  "set_asid_pool ptr pool \<lbrace>valid_sched_pred_strong P\<rbrace>"
  apply (wpsimp simp: set_asid_pool_def wp: set_object_wp_strong get_object_wp)
  by (auto simp: obj_at_kh_kheap_simps vs_all_heap_simps a_type_def fun_upd_def
           split:  kernel_object.splits if_splits)

lemma copy_global_mappings_valid_sched_pred[wp]:
  "copy_global_mappings pd \<lbrace>valid_sched_pred_strong P\<rbrace>"
  by (wpsimp simp: copy_global_mappings_def store_pde_def wp: mapM_x_wp_inv)

lemma init_arch_objects_valid_sched_pred[wp, DetSchedAux_AI_assms]:
  "init_arch_objects new_type ptr num_objects obj_sz refs \<lbrace>valid_sched_pred_strong P\<rbrace>"
  by (wpsimp simp: init_arch_objects_def wp: dmo_valid_sched_pred mapM_x_wp_inv)

crunches init_arch_objects
  for exst[wp]: "\<lambda>s. P (exst s)"
  and ct[wp]: "\<lambda>s. P (cur_thread s)"
  and valid_idle[wp, DetSchedAux_AI_assms]: valid_idle
  (wp: crunch_wps unless_wp)

lemma valid_machine_time_getCurrentTime[DetSchedAux_AI_assms]:
  "valid_machine_time s \<Longrightarrow> (x, s') \<in> fst (getCurrentTime (machine_state s))
   \<Longrightarrow> valid_machine_time_2 x (last_machine_time s')"
  apply (clarsimp simp: valid_machine_time_def getCurrentTime_def in_monad)
  apply (rule word_of_nat_le)
  apply (rule Lattices.linorder_class.min.coboundedI1)
  apply linarith
  done

lemma dmo_getCurrentTime_vmt_sp[wp, DetSchedAux_AI_assms]:
  "\<lbrace>valid_machine_time\<rbrace>
   do_machine_op getCurrentTime
   \<lbrace>\<lambda>rv s. (cur_time s \<le> rv) \<and> (rv \<le> - getCurrentTime_buffer - 1)\<rbrace>"
  supply minus_add_distrib[simp del]
  apply (wpsimp simp: do_machine_op_def)
  apply (clarsimp simp: valid_machine_time_def getCurrentTime_def in_monad)
  apply (intro conjI)
   apply (clarsimp simp: min_def, intro conjI impI)
    subgoal
      apply (rule_tac order.trans, assumption)
      apply (rule_tac order.trans, assumption)
      apply (rule preorder_class.eq_refl)
      apply (subst group_add_class.diff_conv_add_uminus)
      apply (subst minus_one_norm_num)
      apply clarsimp
      apply (insert getCurrentTime_buffer_no_overflow')
      done
   subgoal for s
     apply (subst (asm) linorder_class.not_le)
     apply (rule_tac order.trans, assumption)
     apply (rule no_plus_overflow_unat_size2)
     apply (rule_tac order.trans)
      apply (rule add_le_mono)
       apply (rule preorder_class.eq_refl, simp)
      apply (rule unat_of_nat_closure)
     apply (rule_tac order.trans)
      apply (rule order.strict_implies_order, assumption)
     by (metis unat_minus_one_word word_le_nat_alt word_n1_ge)
  apply (clarsimp simp: min_def, intro conjI impI)
   subgoal
     apply (rule preorder_class.eq_refl)
     apply (subst group_add_class.diff_conv_add_uminus)
     apply (subst minus_one_norm_num)
     apply clarsimp
     apply (insert getCurrentTime_buffer_no_overflow')
     done
  subgoal for s
    apply (subst (asm) linorder_class.not_le)
    apply (rule_tac b="of_nat (unat (last_machine_time (machine_state s)) +
      time_oracle (Suc (time_state (machine_state s))))" in order.trans[rotated])
     apply (rule word_of_nat_le)
     apply (rule_tac order.trans)
      apply (rule order.strict_implies_order, assumption)
     apply (subst group_add_class.diff_conv_add_uminus)
     apply (subst minus_one_norm_num)
     apply clarsimp
     apply (subst unat_sub)
      apply (rule order.trans[OF word_up_bound])
      apply (rule preorder_class.eq_refl)
      apply simp
     apply simp
     apply (subst unat_minus_plus_one)
      apply (insert getCurrentTime_buffer_no_overflow getCurrentTime_buffer_no_overflow')
      apply (clarsimp simp: kernelWCET_ticks_def MAX_PERIOD_def)
     apply (insert getCurrentTime_buffer_no_overflow'_stronger)
     apply (subst unat_add_lem')
      apply (metis no_olen_add_nat word_add_no_overflow word_le_less_eq word_less_iff_unsigned)
     apply fastforce
    apply force
    done
  done

lemma update_time_stamp_valid_machine_time[wp, DetSchedAux_AI_assms]:
  "update_time_stamp \<lbrace>valid_machine_time\<rbrace>"
  unfolding update_time_stamp_def
  apply (wpsimp simp: do_machine_op_def)
  apply (fastforce simp: getCurrentTime_def elim: valid_machine_time_getCurrentTime)
  done

end

global_interpretation DetSchedAux_AI?: DetSchedAux_AI
  proof goal_cases
    interpret Arch .
    case 1 show ?case by (unfold_locales; (fact DetSchedAux_AI_assms)?)
  qed

context Arch begin global_naming ARM

(* FIXME: move? *)
lemma init_arch_objects_obj_at_impossible:
  "\<forall>ao. \<not> P (ArchObj ao) \<Longrightarrow>
    \<lbrace>\<lambda>s. Q (obj_at P p s)\<rbrace> init_arch_objects a b c d e \<lbrace>\<lambda>rv s. Q (obj_at P p s)\<rbrace>"
  by (auto intro: init_arch_objects_obj_at_non_pd)

lemma perform_asid_control_etcb_at:
  "\<lbrace>etcb_at P t\<rbrace>
   perform_asid_control_invocation aci
   \<lbrace>\<lambda>r s. st_tcb_at (Not \<circ> inactive) t s \<longrightarrow> etcb_at P t s\<rbrace>"
  apply (cases aci, rename_tac frame slot parent base)
  apply (simp add: perform_asid_control_invocation_def, thin_tac _)
  apply (rule bind_wp[OF _ delete_objects_etcb_at])
  apply (rule bind_wp[OF _ get_cap_inv])
  apply (rule bind_wp[OF _ set_cap_valid_sched_pred])
  apply (rule bind_wp[OF _ retype_region_etcb_at])
  apply (wpsimp wp: hoare_vcg_const_imp_lift hoare_vcg_imp_lift')
  by (clarsimp simp: pred_tcb_at_def obj_at_def)

crunches perform_asid_control_invocation
  for cur_time[wp]: "\<lambda>s. P (cur_time s)"

lemma perform_asid_control_invocation_bound_sc_obj_tcb_at[wp]:
  "\<lbrace>\<lambda>s. bound_sc_obj_tcb_at (P (cur_time s)) t s
        \<and> ex_nonz_cap_to t s
        \<and> invs s
        \<and> ct_active s
        \<and> scheduler_action s = resume_cur_thread
        \<and> valid_aci aci s \<rbrace>
   perform_asid_control_invocation aci
   \<lbrace>\<lambda>rv s. bound_sc_obj_tcb_at (P (cur_time s)) t s\<rbrace>"
  apply (rule hoare_lift_Pf3[where f=cur_time, rotated], wpsimp)
  by (rule bound_sc_obj_tcb_at_nonz_cap_lift
      ; wpsimp wp: perform_asid_control_invocation_st_tcb_at
                   perform_asid_control_invocation_sc_at_pred_n)

crunches perform_asid_control_invocation
  for idle_thread[wp]: "\<lambda>s. P (idle_thread s)"
  and valid_blocked[wp]: "valid_blocked"
  (wp: hoare_weak_lift_imp)

crunches perform_asid_control_invocation
  for rqueues[wp]: "\<lambda>s. P (ready_queues s)"
  and schedact[wp]: "\<lambda>s. P (scheduler_action s)"
  and cur_domain[wp]: "\<lambda>s. P (cur_domain s)"
  and release_queue[wp]: "\<lambda>s. P (release_queue s)"
  and misc[wp]: "\<lambda>s. P (scheduler_action s) (ready_queues s)
               (cur_domain s) (release_queue s)"

(* FIXME: move to ArchArch_AI *)
lemma perform_asid_control_invocation_obj_at_live:
  assumes csp: "cspace_agnostic_pred P"
  assumes live: "\<forall>ko. P ko \<longrightarrow> live ko"
  shows
  "\<lbrace>\<lambda>s. N (obj_at P p s)
        \<and> invs s
        \<and> ct_active s
        \<and> valid_aci aci s
        \<and> scheduler_action s = resume_cur_thread\<rbrace>
   perform_asid_control_invocation aci
   \<lbrace>\<lambda>rv s. N (obj_at P p s)\<rbrace>"
  apply (clarsimp simp: perform_asid_control_invocation_def split: asid_control_invocation.splits)
  apply (rename_tac region_ptr target_slot_cnode target_slot_idx untyped_slot_cnode untyped_slot_idx asid)
  apply (rule_tac S="region_ptr && ~~mask page_bits = region_ptr \<and> is_aligned region_ptr page_bits
                     \<and> word_size_bits \<le> page_bits \<and> page_bits < word_bits
                     \<and> obj_bits_api (ArchObject ASIDPoolObj) 0 = page_bits" in hoare_gen_asm_spec
         , fastforce simp: valid_aci_def cte_wp_at_caps_of_state valid_cap_simps
                           cap_aligned_def page_bits_def pageBits_def word_size_bits_def
                           obj_bits_api_def default_arch_object_def
                    dest!: caps_of_state_valid[rotated])
  apply (clarsimp simp: delete_objects_rewrite bind_assoc)
  apply (wpsimp wp: cap_insert_cspace_agnostic_obj_at[OF csp]
                    set_cap.cspace_agnostic_obj_at[OF csp]
                    retype_region_obj_at_live[where sz=page_bits, OF live]
                    max_index_upd_invs_simple set_cap_no_overlap get_cap_wp
                    hoare_vcg_ex_lift
         | strengthen invs_valid_objs invs_psp_aligned)+
  apply (frule detype_invariants
         ; clarsimp simp: valid_aci_def cte_wp_at_caps_of_state page_bits_def
                          intvl_range_conv empty_descendants_range_in descendants_range_def2
                          detype_clear_um_independent range_cover_full word_bits_def
                    cong: conj_cong)
  apply (frule pspace_no_overlap_detype[OF caps_of_state_valid_cap]; clarsimp)
  apply (erule rsubst[of N]; rule iffI; clarsimp simp: obj_at_def)
  apply (drule live[THEN spec, THEN mp])
  apply (frule (2) if_live_then_nonz_cap_invs)
  by (frule (2) descendants_of_empty_untyped_range[where p=p]; simp)

lemma perform_asid_control_invocation_pred_tcb_at_live:
  assumes live: "\<forall>tcb. P (proj (tcb_to_itcb tcb)) \<longrightarrow> live (TCB tcb)"
  shows
  "\<lbrace>\<lambda>s. N (pred_tcb_at proj P p s)
        \<and> invs s
        \<and> ct_active s
        \<and> valid_aci aci s
        \<and> scheduler_action s = resume_cur_thread\<rbrace>
   perform_asid_control_invocation aci
   \<lbrace>\<lambda>rv s. N (pred_tcb_at proj P p s)\<rbrace>"
  unfolding pred_tcb_at_def using live
  by (auto intro!: perform_asid_control_invocation_obj_at_live simp: cspace_agnostic_pred_def tcb_to_itcb_def)

lemma perform_asid_control_invocation_sc_at_pred_n_live:
  assumes live: "\<forall>sc. P (proj sc) \<longrightarrow> live_sc sc"
  shows
  "\<lbrace>\<lambda>s. Q (sc_at_pred_n N proj P p s)
        \<and> invs s
        \<and> ct_active s
        \<and> valid_aci aci s
        \<and> scheduler_action s = resume_cur_thread\<rbrace>
   perform_asid_control_invocation aci
   \<lbrace>\<lambda>rv s. Q (sc_at_pred_n N proj P p s)\<rbrace>"
  unfolding sc_at_pred_n_def using live
  by (auto intro!: perform_asid_control_invocation_obj_at_live simp: cspace_agnostic_pred_def live_def)

lemma perform_asid_control_invocation_valid_idle:
  "\<lbrace>invs and ct_active
         and valid_aci aci
         and (\<lambda>s. scheduler_action s = resume_cur_thread)\<rbrace>
   perform_asid_control_invocation aci
   \<lbrace>\<lambda>_. valid_idle\<rbrace>"
  by (strengthen invs_valid_idle) wpsimp

crunches perform_asid_control_invocation
  for lmt[wp]: "\<lambda>s. P (last_machine_time_of s)"
  (ignore: do_machine_op
     simp: detype_def crunch_simps
       wp: do_machine_op_machine_state dxo_wp_weak crunch_wps)

lemma perform_asid_control_invocation_pred_map_sc_refill_cfgs_of:
  "perform_asid_control_invocation aci
   \<lbrace>\<lambda>s. pred_map active_scrc (sc_refill_cfgs_of s) p
        \<longrightarrow> pred_map P (sc_refill_cfgs_of s) p\<rbrace>"
  unfolding perform_asid_control_invocation_def
  by (wpsimp wp: delete_objects_pred_map_sc_refill_cfgs_of
           comb: hoare_drop_imp)

lemma perform_asid_control_invocation_implies_zero_budget:
  "perform_asid_control_invocation aci
   \<lbrace>\<lambda>s. pred_map Q (sc_refill_cfgs_of s) p
        \<longrightarrow> pred_map (\<lambda>cfg. scrc_budget cfg = 0) (sc_refill_cfgs_of s) p\<rbrace>"
  unfolding perform_asid_control_invocation_def
  by (wpsimp wp: delete_objects_pred_map_sc_refill_cfgs_of
           comb: hoare_drop_imp)

lemma perform_asid_control_invocation_sporadic_implies:
  "perform_asid_control_invocation aci
   \<lbrace>\<lambda>s. pred_map (\<lambda>cfg. scrc_sporadic cfg) (sc_refill_cfgs_of s) p
        \<longrightarrow> pred_map Q (sc_refill_cfgs_of s) p\<rbrace>"
  unfolding perform_asid_control_invocation_def
  by (wpsimp wp: delete_objects_pred_map_sc_refill_cfgs_of
           comb: hoare_drop_imp)

crunches perform_asid_control_invocation
  for valid_machine_time[wp]: "valid_machine_time"
  and cur_sc[wp]: "\<lambda>s. P (cur_sc s)"

lemma perform_asid_control_invocation_valid_sched:
  "\<lbrace>ct_active and (\<lambda>s. scheduler_action s = resume_cur_thread) and invs and valid_aci aci and
    valid_sched and valid_machine_time and valid_idle\<rbrace>
     perform_asid_control_invocation aci
   \<lbrace>\<lambda>_. valid_sched\<rbrace>"
  apply (rule hoare_pre)
   apply (rule_tac I="invs and ct_active and
                      (\<lambda>s. scheduler_action s = resume_cur_thread) and valid_aci aci"
          in valid_sched_tcb_state_preservation_gen)
                 apply simp
                 apply (wpsimp wp: perform_asid_control_invocation_st_tcb_at
                                   perform_asid_control_invocation_pred_tcb_at_live
                                   perform_asid_control_invocation_sc_at_pred_n_live[where Q="Not"]
                                   perform_asid_control_etcb_at
                                   perform_asid_control_invocation_sc_at_pred_n
                                   perform_asid_control_invocation_valid_idle
                                   perform_asid_control_invocation_pred_map_sc_refill_cfgs_of
                                   perform_asid_control_invocation_implies_zero_budget
                                   perform_asid_control_invocation_sporadic_implies
                                   hoare_vcg_all_lift
                             simp: ipc_queued_thread_state_live live_sc_def)+
  done

lemma perform_asid_control_invocation_cur_sc_active:
  "\<lbrace>cur_sc_active and invs and ct_active and schact_is_rct and valid_aci aci\<rbrace>
   perform_asid_control_invocation aci
   \<lbrace>\<lambda>_. cur_sc_active\<rbrace>"
  apply (subst cur_sc_active_rewrite)+
  apply (rule hoare_weaken_pre)
   apply (rule_tac f=cur_sc in hoare_lift_Pf2)
    apply (rule perform_asid_control_invocation_non_cspace_obj_at)
    apply (clarsimp simp: cnode_agnostic_pred_def tcb_cnode_agnostic_pred_def)
   apply wpsimp
  apply (fastforce intro!: if_live_then_nonz_capD
                     simp: invs_def valid_state_def cur_sc_tcb_def sc_at_pred_n_def obj_at_def
                           ct_in_state_def pred_tcb_at_def valid_idle_def schact_is_rct_def
                           live_def live_sc_def)
  done

lemma kernelWCET_us_non_zero:
  "kernelWCET_us \<noteq> 0"
  using kernelWCET_us_pos by fastforce

lemma kernelWCET_ticks_non_zero:
  "kernelWCET_ticks \<noteq> 0"
  apply (clarsimp simp: kernelWCET_ticks_def)
  using kernelWCET_pos'
  by simp

end
end
