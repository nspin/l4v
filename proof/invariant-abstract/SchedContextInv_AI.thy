(*
 * Copyright 2020, Data61, CSIRO (ABN 41 687 119 230)
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

theory SchedContextInv_AI
  imports "./$L4V_ARCH/ArchIpc_AI" "IpcDet_AI"

begin

lemma tcb_yield_to_noncap: "tcb_at p s \<Longrightarrow>
  obj_at (same_caps (TCB (tcb_yield_to_update (\<lambda>y. new) (the (get_tcb p s))))) p s"
  apply (clarsimp simp: obj_at_def is_tcb_def)
  by (case_tac ko; clarsimp simp: ran_tcb_cap_cases get_tcb_rev)

lemma set_consumed_valid_objs[wp]:
  "\<lbrace>valid_objs\<rbrace> set_consumed scptr args \<lbrace>\<lambda>rv. valid_objs\<rbrace>"
  by (wpsimp simp: set_consumed_def)

lemma set_consumed_valid_idle[wp]:
  "\<lbrace>valid_idle\<rbrace> set_consumed scptr args \<lbrace>\<lambda>rv. valid_idle\<rbrace>"
  by (wpsimp simp: set_consumed_def)

lemma set_consumed_only_idle[wp]:
  "\<lbrace>only_idle\<rbrace> set_consumed scptr args \<lbrace>\<lambda>rv. only_idle\<rbrace>"
  by (wpsimp simp: set_consumed_def)

lemma set_consumed_iflive[wp]:
  "\<lbrace>if_live_then_nonz_cap\<rbrace> set_consumed scptr args \<lbrace>\<lambda>rv. if_live_then_nonz_cap\<rbrace>"
  by (wpsimp simp: set_consumed_def)

lemma set_mrs_tcb_at_ct[wp]:
  "\<lbrace>\<lambda>s. tcb_at (cur_thread s) s\<rbrace> set_mrs thread buf msgs \<lbrace>\<lambda>rv s. tcb_at (cur_thread s) s\<rbrace>"
  apply (simp add: set_mrs_redux zipWithM_x_mapM split_def
                   store_word_offs_def
             cong: option.case_cong
              del: upt.simps)
  apply (wp mapM_wp' set_object_wp | wpcw | clarsimp dest!: get_tcb_SomeD
          | simp add: do_machine_op_def thread_set_def tcb_at_typ obj_at_def)+
  done

lemma as_user_tcb_ct[wp]:
  "\<lbrace>\<lambda>s. tcb_at (cur_thread s) s\<rbrace> as_user t m \<lbrace>\<lambda>rv s. tcb_at (cur_thread s) s\<rbrace>"
  apply (simp add: as_user_def split_def)
  apply (wpsimp simp: wp: set_object_wp)
  apply (clarsimp simp: obj_at_def is_tcb)
  done

lemma as_user_ex_nonz[wp]:
  "\<lbrace>\<lambda>s. ex_nonz_cap_to (cur_thread s) s\<rbrace> as_user t m \<lbrace>\<lambda>rv s. ex_nonz_cap_to (cur_thread s) s\<rbrace>"
  apply (simp add: as_user_def split_def)
  apply (wpsimp simp: wp: set_object_wp)
  apply (clarsimp simp: ex_nonz_cap_to_def)
  apply (rule_tac x=aa in exI)
  apply (rule_tac x=ba in exI)
  apply (case_tac "t=aa", simp)
   defer
   apply (drule upd_other_cte_wp_at)
    prefer 2
    apply simp
   apply simp
  apply (clarsimp simp: fun_upd_def, subst cte_wp_at_after_update)
   apply (clarsimp simp: same_caps_def obj_at_def ran_tcb_cap_cases dest!: get_tcb_SomeD)
  by simp

lemma set_mrs_ex_nonz_ct[wp]:
  "\<lbrace>\<lambda>s. ex_nonz_cap_to (cur_thread s) s\<rbrace> set_mrs thread buf msgs \<lbrace>\<lambda>rv s. ex_nonz_cap_to (cur_thread s) s\<rbrace>"
  apply (rule set_mrs_thread_set_dmo)
   apply (wpsimp wp: ex_nonz_cap_to_pres simp: thread_set_def wp: set_object_wp simp_del: fun_upd_apply)
   apply (clarsimp dest!: get_tcb_SomeD simp: ex_nonz_cap_to_def simp del: fun_upd_apply)
   apply (rule_tac x=a in exI)
   apply (rule_tac x=b in exI)
   apply (case_tac "a=thread", simp)
    defer
    apply (drule upd_other_cte_wp_at)
     apply simp
    apply simp
   prefer 2
   apply (clarsimp simp: fun_upd_def, subst cte_wp_at_after_update)
    apply (clarsimp simp: same_caps_def obj_at_def ran_tcb_cap_cases dest!: get_tcb_SomeD)
   apply simp
  apply (wpsimp simp: do_machine_op_def ex_nonz_cap_to_def)
  done


crunch set_message_info, set_mrs, set_consumed
  for tcb_at_ct[wp]: "\<lambda>s. tcb_at (cur_thread s) s"
  and ex_nonz_cap_to_ct[wp]: "\<lambda>s. ex_nonz_cap_to (cur_thread s) s"
  (wp: valid_bound_tcb_typ_at set_object_typ_at mapM_wp
   ignore: set_object as_user simp: zipWithM_x_mapM)

lemma set_consumed_cap_refs_in_kernel_window[wp]:
  "\<lbrace>cap_refs_in_kernel_window\<rbrace> set_consumed scptr args \<lbrace>\<lambda>rv. cap_refs_in_kernel_window\<rbrace>"
  by (wpsimp simp: set_consumed_def ran_tcb_cap_cases)

lemma set_consumed_cap_refs_respects_device_region[wp]:
  "\<lbrace>cap_refs_respects_device_region\<rbrace> set_consumed scptr args \<lbrace>\<lambda>rv. cap_refs_respects_device_region\<rbrace>"
  by (wpsimp simp: set_consumed_def ran_tcb_cap_cases)

crunch set_thread_state_act
 for it_ct[wp]: "\<lambda>s. P (idle_thread s) (cur_thread s)"

crunch set_consumed
  for state_hyp_refs_of[wp]: "\<lambda>s. P (state_hyp_refs_of s)"
  and valid_global_refs[wp]: "valid_global_refs"
  and pspace_respects_device_region[wp]: "pspace_respects_device_region"
  (simp: Let_def tcb_yield_to_noncap zipWithM_x_mapM
   wp: hoare_drop_imps crunch_wps maybeM_inv ignore: lookup_ipc_buffer)

crunch complete_yield_to
 for aligned[wp]: pspace_aligned
 and distinct[wp]: pspace_distinct
 and tcb_at[wp]: "tcb_at t"
 and no_cdt[wp]: "\<lambda>s. P (cdt s)"
 and state_hyp_refs_of[wp]: "\<lambda>s. P (state_hyp_refs_of s)"
 and no_revokable[wp]: "\<lambda>s. P (is_original_cap s)"
 and valid_global_objs[wp]: "valid_global_objs"
 and valid_global_vspace_mappings[wp]: "valid_global_vspace_mappings"
 and valid_arch_caps[wp]: "valid_arch_caps"
 and ifunsafe[wp]: "if_unsafe_then_cap"
 and valid_arch[wp]: "valid_arch_state"
 and valid_irq_states[wp]: "valid_irq_states"
 and vms[wp]: "valid_machine_state"
 and valid_vspace_objs[wp]: "valid_vspace_objs"
 and valid_global_refs[wp]: "valid_global_refs"
 and v_ker_map[wp]: "valid_kernel_mappings"
 and equal_mappings[wp]: "equal_kernel_mappings"
 and valid_asid_map[wp]: "valid_asid_map"
 and pspace_in_kernel_window[wp]: "pspace_in_kernel_window"
 and cap_refs_in_kernel_window[wp]: "cap_refs_in_kernel_window"
 and cap_refs_respects_device_region[wp]: "cap_refs_respects_device_region"
 and pspace_respects_device_region[wp]: "pspace_respects_device_region"
 and cur_tcb[wp]: "cur_tcb"
 and valid_ioc[wp]: "valid_ioc"
 and interrupt_states[wp]: "\<lambda>s. P (interrupt_states s)"
 and valid_irq_handlers[wp]: "valid_irq_handlers"
 and valid_mdb[wp]: valid_mdb
 and zombies[wp]: zombies_final
  (wp: maybeM_inv hoare_drop_imp sts_only_idle sts_valid_idle
   ignore: set_tcb_obj_ref get_sched_context)

lemma valid_idle_sc_update:
  "\<lbrakk>valid_idle s; ko_at (SchedContext sc n) p s;
     sc_period sc = sc_period sc';
     sc_tcb sc = sc_tcb sc';
     sc_ntfn sc = sc_ntfn sc';
     sc_refill_max sc = sc_refill_max sc';
     sc_badge sc = sc_badge sc';
     sc_yield_from sc = sc_yield_from sc';
     sc_replies sc = sc_replies sc' \<rbrakk>
   \<Longrightarrow> valid_idle (s\<lparr>kheap := (kheap s)(p \<mapsto> SchedContext sc' n)\<rparr>)"
  by (fastforce simp: valid_idle_def pred_tcb_at_def obj_at_def)

lemma sched_context_cancel_yield_to_valid_idle[wp]:
  "\<lbrace>\<lambda>s. valid_idle s \<and> sym_refs (state_refs_of s)\<rbrace>
   sched_context_cancel_yield_to tcb_ptr
   \<lbrace>\<lambda>rv. valid_idle\<rbrace>"
  unfolding sched_context_cancel_yield_to_def  maybeM_def get_tcb_obj_ref_def
  apply (rule bind_wp[OF _ thread_get_sp])
  apply (case_tac yt_opt; simp)
   apply wpsimp
  apply (wpsimp wp: update_sched_context_valid_idle thread_get_wp')
  apply (clarsimp simp: obj_at_def valid_idle_def pred_tcb_at_def)
  apply (clarsimp simp: sym_refs_def)
  apply (erule_tac x = tcb_ptr in allE)
  apply (auto simp: valid_idle_def obj_at_def state_refs_of_def default_sched_context_def)
  done

lemma sched_context_cancel_yield_to_only_idle[wp]:
  "sched_context_cancel_yield_to tcb_ptr \<lbrace>only_idle\<rbrace>"
  by (wpsimp simp: sched_context_cancel_yield_to_def maybeM_def get_tcb_obj_ref_def)

lemma sched_context_cancel_yield_to_iflive[wp]:
  "sched_context_cancel_yield_to tcb_ptr \<lbrace>if_live_then_nonz_cap\<rbrace>"
  by (wpsimp simp: sched_context_cancel_yield_to_def maybeM_def get_tcb_obj_ref_def)

lemma sched_context_cancel_yield_to_ex_nonz_cap_to[wp]:
  "sched_context_cancel_yield_to tcb_ptr \<lbrace>ex_nonz_cap_to p\<rbrace>"
  by (wpsimp simp: sched_context_cancel_yield_to_def maybeM_def get_tcb_obj_ref_def)

crunch complete_yield_to
  for valid_idle[wp]: valid_idle
  and only_idle[wp]: only_idle
  and if_live[wp]: if_live_then_nonz_cap
  and ex_nonz[wp]: "ex_nonz_cap_to p"
  (wp: crunch_wps set_tcb_obj_ref_wp update_sched_context_wp simp: crunch_simps)

crunch complete_yield_to
 for it_ct[wp]: "\<lambda>s. P (idle_thread s) (cur_thread s)"
  (wp: maybeM_inv lookup_ipc_buffer_inv hoare_drop_imps crunch_wps simp: crunch_simps)

lemma set_thread_state_bound_yt_tcb_at[wp]:
  "\<lbrace>bound_yt_tcb_at P t\<rbrace> set_thread_state p ts \<lbrace>\<lambda>_. bound_yt_tcb_at P t\<rbrace>"
  unfolding set_thread_state_def
  by (wpsimp simp: pred_tcb_at_def obj_at_def get_tcb_def wp: set_object_wp)

crunch set_thread_state_act
  for kheap_cur[wp]: "\<lambda>s. P (kheap s) (cur_thread s)"
  and obj_at_cur[wp]: "\<lambda>s. P (obj_at (Q (cur_thread s)) p s)"

lemma set_thread_state_bound_yt_tcb_at_ct[wp]:
  "\<lbrace>\<lambda>s. bound_yt_tcb_at P (cur_thread s) s\<rbrace>
     set_thread_state p ts \<lbrace>\<lambda>_ s. bound_yt_tcb_at P (cur_thread s) s\<rbrace>"
  unfolding set_thread_state_def
  by (wpsimp simp: pred_tcb_at_def obj_at_def get_tcb_def wp: set_object_wp)

lemma sssc_sc_yf_update_bound_yt_tcb_at_ct[wp]:
  "\<lbrace>\<lambda>s. bound_yt_tcb_at P (cur_thread s) s\<rbrace>
   set_sc_obj_ref sc_yield_from_update scp tcb
   \<lbrace>\<lambda>_ s. bound_yt_tcb_at P (cur_thread s) s\<rbrace>"
  unfolding update_sched_context_def set_object_def
  by (wpsimp simp: pred_tcb_at_def obj_at_def  wp: get_object_wp)

lemma sched_context_cancel_yield_to_bound_yt_tcb_at[wp]:
  "\<lbrace> bound_yt_tcb_at P t and K (t \<noteq> tcb_ptr) \<rbrace>
   sched_context_cancel_yield_to tcb_ptr
   \<lbrace>\<lambda>rv. bound_yt_tcb_at P t \<rbrace>"
  apply (rule hoare_gen_asm)
  apply (clarsimp simp: sched_context_cancel_yield_to_def)
  by (wpsimp simp: obj_at_def wp: hoare_vcg_ex_lift sbn_st_tcb_at_neq  hoare_drop_imp)

lemma complete_yield_to_bound_yt_tcb_at[wp]:
  "\<lbrace> bound_yt_tcb_at P t and K (t \<noteq> tcb_ptr) \<rbrace>
   complete_yield_to tcb_ptr
   \<lbrace>\<lambda>rv. bound_yt_tcb_at P t \<rbrace>"
  by (wpsimp simp: complete_yield_to_def wp: lookup_ipc_buffer_inv hoare_drop_imp)

crunch do_machine_op, store_word_offs
  for pred_tcb_at_ct[wp]: "\<lambda>s. Q (pred_tcb_at proj P (cur_thread s) s)"

lemma set_mrs_pred_tcb_at_ct[wp]:
  "\<lbrace>(\<lambda>s. pred_tcb_at proj P (cur_thread s) s)\<rbrace>
    set_mrs thread buf msgs \<lbrace>\<lambda>_ s. pred_tcb_at proj P (cur_thread s) s\<rbrace>"
  apply (clarsimp simp: set_mrs_def)
  apply (wpsimp split_del: if_split simp: zipWithM_x_mapM wp: mapM_wp' set_object_wp)
  apply (clarsimp simp: pred_tcb_at_def obj_at_def tcb_to_itcb_def dest!: get_tcb_SomeD)
  done

(* FIXME: replace this with as_user_pred_tcb_at which is stronger *)
lemma as_user_pred_tcb_at_ct[wp]:
  "\<lbrace>(\<lambda>s. pred_tcb_at proj P (cur_thread s) s)\<rbrace>
    as_user tptr f \<lbrace>\<lambda>_ s. pred_tcb_at proj P (cur_thread s) s\<rbrace>"
  apply (clarsimp simp: as_user_def)
  apply (wpsimp split_del: if_split simp: split_def wp: set_object_wp)
  apply (clarsimp simp: pred_tcb_at_def obj_at_def tcb_to_itcb_def dest!: get_tcb_SomeD)
  done

lemma set_message_info_pred_tcb_at_ct[wp]:
  "\<lbrace>(\<lambda>s. pred_tcb_at proj P (cur_thread s) s)\<rbrace>
    set_message_info tptr f \<lbrace>\<lambda>_ s. pred_tcb_at proj P (cur_thread s) s\<rbrace>"
  by (wpsimp split_del: if_split simp: set_message_info_def split_def set_object_def)

lemma sched_context_update_consumed_pred_tcb_at_ct[wp]:
  "\<lbrace>(\<lambda>s. pred_tcb_at proj P (cur_thread s) s)\<rbrace>
    sched_context_update_consumed sc_ptr \<lbrace>\<lambda>_ s. pred_tcb_at proj P (cur_thread s) s\<rbrace>"
  apply (clarsimp simp: sched_context_update_consumed_def)
  apply (wpsimp wp: get_object_wp hoare_drop_imp get_sched_context_wp
              simp: split_def update_sched_context_def set_object_def)
  apply (fastforce simp: pred_tcb_at_def obj_at_def tcb_to_itcb_def)
  done

lemma set_consumed_pred_tcb_at_ct[wp]:
  "\<lbrace>(\<lambda>s. pred_tcb_at proj P (cur_thread s) s)\<rbrace>
    set_consumed sc_ptr args \<lbrace>\<lambda>_ s. pred_tcb_at proj P (cur_thread s) s\<rbrace>"
  apply (clarsimp simp: set_consumed_def)
  apply (wpsimp split_del: if_split simp: split_def set_object_def)
  done

lemma update_sched_context_sc_at_pred_n_no_change:
  "\<forall>sc. P (proj sc) \<longrightarrow> P (proj (f sc)) \<Longrightarrow>
   update_sched_context sc_ptr f \<lbrace>sc_at_pred_n Q proj P scptr'\<rbrace>"
  apply (wpsimp wp: update_sched_context_wp)
  by (clarsimp simp: sc_at_pred_n_def obj_at_def)

lemma sched_context_unbind_ntfn_sc_tcb_sc_at[wp]:
  "sched_context_unbind_ntfn scptr \<lbrace>sc_tcb_sc_at Q scptr\<rbrace>"
  unfolding sched_context_unbind_ntfn_def
  by (wpsimp wp: update_sched_context_sc_at_pred_n_no_change simp: get_sc_obj_ref_def)

lemma sched_context_unbind_reply_sc_tcb_sc_at[wp]:
  "sched_context_unbind_reply scptr \<lbrace>sc_tcb_sc_at Q scptr\<rbrace>"
  unfolding sched_context_unbind_reply_def
  by (wpsimp wp: update_sched_context_sc_at_pred_n_no_change simp: get_sc_obj_ref_def)

lemma sched_context_unbind_all_tcbs_sc_tcb_sc_at_None[wp]:
  "\<lbrace>K (scptr \<noteq> idle_sc_ptr)\<rbrace>
   sched_context_unbind_all_tcbs scptr
   \<lbrace>\<lambda>rv. sc_tcb_sc_at (\<lambda>x. x = None) scptr\<rbrace>"
  unfolding sched_context_unbind_all_tcbs_def sched_context_unbind_tcb_def
  apply (wpsimp wp: update_sched_context_wp set_object_wp
              simp: set_tcb_obj_ref_def)
         apply (rule_tac Q'="\<top>\<top>" in hoare_strengthen_post[rotated])
          apply (clarsimp simp: obj_at_def sc_at_pred_n_def)
         apply (wpsimp+)[7]
  apply (clarsimp simp: obj_at_def sc_at_pred_n_def)
  done

crunch store_word_offs
 for sc_tcb_sc_at[wp]: "\<lambda>s. sc_tcb_sc_at P scp s"
  (simp: crunch_simps wp: crunch_wps hoare_drop_imps)

lemma sched_context_update_consumed_sc_tcb_sc_at_inv'_none[wp]:
  "sched_context_update_consumed sp \<lbrace> \<lambda>s. sc_tcb_sc_at P scp s\<rbrace>"
  apply (simp add: sched_context_update_consumed_def)
  apply (wpsimp wp: get_object_wp get_sched_context_wp hoare_drop_imp split_del: if_split
           simp: split_def update_sched_context_def set_object_def)
  by (clarsimp simp: sc_tcb_sc_at_def obj_at_def)

lemma set_consumed_sc_tcb_sc_at_inv'_none[wp]:
  "set_consumed sp buf \<lbrace> \<lambda>s. sc_tcb_sc_at P scp s\<rbrace>"
  apply (simp add: set_consumed_def)
  by (wpsimp wp: get_object_wp mapM_wp' hoare_drop_imp split_del: if_split
           simp: split_def set_message_info_def as_user_def set_mrs_def set_object_def
                 sc_tcb_sc_at_def zipWithM_x_mapM)

lemma sched_context_unbind_yield_from_sc_tcb_sc_at[wp]:
  "sched_context_unbind_yield_from scptr \<lbrace>sc_tcb_sc_at P scptr\<rbrace>"
  unfolding sched_context_unbind_yield_from_def complete_yield_to_def sched_context_cancel_yield_to_def
  by (wpsimp wp: update_sched_context_sc_at_pred_n_no_change hoare_drop_imps)

lemma complete_yield_to_bound_yt_tcb_a_ct[wp]:
  "\<lbrace> (\<lambda>s. bound_yt_tcb_at ((=) None) (cur_thread s) s) \<rbrace>
      complete_yield_to tcb_ptr \<lbrace>\<lambda>rv s. bound_yt_tcb_at ((=) None) (cur_thread s) s \<rbrace>"
  apply (clarsimp simp: complete_yield_to_def sched_context_cancel_yield_to_def)
  apply (wpsimp simp: obj_at_def set_tcb_obj_ref_def set_object_def fun_upd_idem
      wp: hoare_vcg_ex_lift sbn_st_tcb_at_neq lookup_ipc_buffer_inv hoare_drop_imp)
       apply (rule_tac Q'="\<lambda>_ s. bound_yt_tcb_at ((=) None) (cur_thread s) s" in hoare_strengthen_post)
        apply (wpsimp simp: pred_tcb_at_def)
       apply (clarsimp simp: pred_tcb_at_def obj_at_def)
      apply (wpsimp wp: lookup_ipc_buffer_inv hoare_drop_imp)+
  done

lemma sts_sc_tcb_sc_at_not_ct[wp]:
  "\<lbrace> \<lambda>s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>
   set_thread_state t s \<lbrace> \<lambda>rv s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>"
  apply (simp add: set_thread_state_def)
  apply (wp set_object_wp | simp add: sc_tcb_sc_at_def)+
  by (clarsimp simp: obj_at_def is_tcb get_tcb_def split: kernel_object.splits)

lemma ssyf_sc_tcb_sc_at_not_ct[wp]:
  "\<lbrace> \<lambda>s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>
   set_sc_obj_ref sc_yield_from_update sp new
   \<lbrace> \<lambda>rv s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>"
  apply (simp add: update_sched_context_def)
  apply (wp get_object_wp | simp add: set_object_def sc_tcb_sc_at_def | wpc)+
  by (clarsimp simp: obj_at_def is_tcb get_tcb_def split: kernel_object.splits)

lemma styt_sc_tcb_sc_at_not_ct[wp]:
  "\<lbrace> \<lambda>s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>
   set_tcb_obj_ref tcb_yield_to_update  sp new \<lbrace> \<lambda>rv s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>"
  apply (simp add: set_tcb_obj_ref_def)
  apply (wp get_object_wp | simp add: set_object_def sc_tcb_sc_at_def | wpc)+
  by (clarsimp simp: obj_at_def is_tcb get_tcb_def split: kernel_object.splits)

crunch do_machine_op
 for sc_tcb_sc_at_not_ct[wp]: "\<lambda>s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s"
  (simp: crunch_simps split_def sc_tcb_sc_at_def wp: crunch_wps hoare_drop_imps)

crunch store_word_offs
 for sc_tcb_sc_at_not_ct[wp]: "\<lambda>s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s"
  (simp: crunch_simps split_def wp: crunch_wps hoare_drop_imps ignore: do_machine_op)

lemma set_mrs_sc_tcb_sc_at_not_ct[wp]:
  "\<lbrace> \<lambda>s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>
   set_mrs thread buf msgs \<lbrace> \<lambda>rv s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>"
  apply (simp add: set_mrs_def)
  apply (wpsimp wp: get_object_wp mapM_wp' hoare_drop_imp split_del: if_split
         simp: split_def set_object_def zipWithM_x_mapM)
  by (clarsimp simp: sc_tcb_sc_at_def obj_at_def dest!: get_tcb_SomeD)

lemma set_message_info_sc_tcb_sc_at_not_ct[wp]:
  "\<lbrace> \<lambda>s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>
   set_message_info thread info \<lbrace> \<lambda>rv s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>"
  apply (simp add: set_message_info_def)
  apply (wpsimp wp: get_object_wp hoare_drop_imp split_del: if_split
          simp: split_def as_user_def set_object_def)
  by (clarsimp simp: sc_tcb_sc_at_def obj_at_def dest!: get_tcb_SomeD)

lemma sched_context_update_consumed_sc_tcb_sc_at_not_ct[wp]:
  "\<lbrace> \<lambda>s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>
   sched_context_update_consumed sp \<lbrace> \<lambda>rv s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>"
  apply (simp add: sched_context_update_consumed_def)
  apply (wpsimp wp: get_object_wp get_sched_context_wp hoare_drop_imp split_del: if_split
           simp: split_def update_sched_context_def set_object_def)
  by (clarsimp simp: sc_tcb_sc_at_def obj_at_def)

lemma set_consumed_sc_tcb_sc_at_not_ct[wp]:
  "\<lbrace> \<lambda>s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>
   set_consumed sp buf \<lbrace> \<lambda>rv s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s\<rbrace>"
  apply (simp add: set_consumed_def)
  by (wpsimp wp: get_object_wp mapM_wp' hoare_drop_imp split_del: if_split
 simp: split_def set_message_info_def as_user_def set_mrs_def set_object_def sc_tcb_sc_at_def zipWithM_x_mapM)

lemma complete_yield_to_sc_tcb_sc_at[wp]:
  "complete_yield_to tcb_ptr \<lbrace>sc_tcb_sc_at P scp \<rbrace>"
  apply (clarsimp simp: complete_yield_to_def sched_context_cancel_yield_to_def)
  by (wpsimp wp: update_sched_context_sc_at_pred_n_no_change hoare_drop_imps)

crunch set_thread_state_act
  for ex_nonz_cap_to_ct[wp]: "\<lambda>s. ex_nonz_cap_to (cur_thread s) s"

lemma sts_ex_nonz_cap_to_ct[wp]:
  "\<lbrace>\<lambda>s. ex_nonz_cap_to (cur_thread s) s\<rbrace> set_thread_state t st \<lbrace>\<lambda>rv s. ex_nonz_cap_to (cur_thread s) s\<rbrace>"
  by (rule hoare_lift_Pf[where f=cur_thread]; wpsimp)

lemma set_tcb_yt_ex_nonz_cap_to_ct[wp]:
  "\<lbrace>\<lambda>s. ex_nonz_cap_to (cur_thread s) s\<rbrace> set_tcb_obj_ref tcb_yield_to_update p v \<lbrace>\<lambda>rv s. ex_nonz_cap_to (cur_thread s) s\<rbrace>"
  by (rule hoare_lift_Pf[where f=cur_thread]; wpsimp)

lemma complete_yield_to_ex_nonz_ct[wp]:
  "\<lbrace>\<lambda>s. ex_nonz_cap_to (cur_thread s) s\<rbrace> complete_yield_to tcb_ptr \<lbrace>\<lambda>rv s. ex_nonz_cap_to (cur_thread s) s\<rbrace>"
  by (rule hoare_lift_Pf[where f=cur_thread]; wpsimp)

lemma set_yf_sc_yf_sc_at:
  "\<lbrace>K (scp'= scp)\<rbrace>
   set_sc_obj_ref sc_yield_from_update scp' k
   \<lbrace>\<lambda>rv. sc_yf_sc_at (\<lambda>b. b = k) scp\<rbrace>"
  apply (wpsimp wp: update_sched_context_wp)
  apply (clarsimp simp: sc_at_pred_n_def obj_at_def)
  done

lemma set_consumed_sc_yf_sc_at_inv'_none[wp]:
  "set_consumed sp buf \<lbrace> \<lambda>s. sc_yf_sc_at P scp s\<rbrace>"
  apply (simp add: set_consumed_def sched_context_update_consumed_def)
  by (wpsimp wp: update_sched_context_wp hoare_drop_imp simp: sc_yf_sc_at_def)
     (fastforce simp: obj_at_def)

lemma sched_context_cancel_yield_to_sc_yf_sc_at_None:
  "\<lbrace>sc_yf_sc_at ((=) (Some tptr)) scp and invs\<rbrace>
   sched_context_cancel_yield_to tptr
   \<lbrace>\<lambda>rv. sc_yf_sc_at ((=) None) scp\<rbrace>"
  unfolding sched_context_cancel_yield_to_def
  apply (clarsimp simp: sc_at_pred_n_eq_commute)
  apply (wpsimp wp: set_yf_sc_yf_sc_at thread_get_wp simp: get_tcb_obj_ref_def)
  apply (clarsimp simp: obj_at_def sc_at_pred_n_def)
  by (fastforce dest!: sym_ref_sc_yf[OF invs_sym_refs])

lemma complete_yield_to_sc_yf_sc_at_None:
  "\<lbrace>sc_yf_sc_at ((=) (Some tptr)) scp and invs\<rbrace>
   complete_yield_to tptr
   \<lbrace>\<lambda>rv. sc_yf_sc_at ((=) None) scp\<rbrace>"
  unfolding complete_yield_to_def maybeM_def
  apply (wpsimp wp: sched_context_cancel_yield_to_sc_yf_sc_at_None thread_get_wp'
              simp: get_tcb_obj_ref_def)
  apply (clarsimp simp: obj_at_def sc_at_pred_n_def)
  apply (subgoal_tac "bound_yt_tcb_at (\<lambda>b. b = (Some scp)) tptr s")
   apply (clarsimp simp: obj_at_def sc_at_pred_n_def pred_tcb_at_def)
  apply (subgoal_tac "(scp, TCBYieldTo) \<in> state_refs_of s tptr")
   apply (clarsimp simp: pred_tcb_at_def obj_at_def state_refs_of_def refs_of_def
                  split: option.splits)
   apply ( clarsimp simp: get_refs_def split: option.splits)
  apply (rule sym_refsE; clarsimp)
  apply (clarsimp simp: pred_tcb_at_def obj_at_def state_refs_of_def refs_of_def
                 split: option.splits dest!: sym[of "Some _"])
  done

crunch sched_context_resume (* FIXME: investigate why wps doesn't work in the lemma below *)
  for tcb_at_ct[wp]: "\<lambda>s. tcb_at (cur_thread s) s"
  and ex_cap_ct[wp]: "\<lambda>s. ex_nonz_cap_to (cur_thread s) s"
  and state_refs_of_ct[wp]: "\<lambda>s. P (state_refs_of s) (cur_thread s)"
  and it_ct[wp]: "\<lambda>s. P (idle_thread s) (cur_thread s)"
  (wp: crunch_wps simp: crunch_simps)

lemma sched_context_yield_to_invs:
  notes refs_of_simps [simp del]
  shows
  "\<lbrace>invs and (\<lambda>s. cur_thread s \<noteq> idle_thread s ) \<comment> \<open> cur_thread must be set to Restart \<close>
    and (\<lambda>s. bound_yt_tcb_at ((=) None) (cur_thread s) s)
    and (\<lambda>s. sc_tcb_sc_at (\<lambda>sctcb.\<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s)
    and (\<lambda>s. ex_nonz_cap_to (cur_thread s) s) and ex_nonz_cap_to scp\<rbrace>
       sched_context_yield_to scp args \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (unfold sched_context_yield_to_def get_sc_obj_ref_def bind_assoc)
  apply (rule bind_wp[OF _ get_sched_context_sp])
  apply clarsimp
  apply (rule bind_wp[where Q'=
          "\<lambda>_. invs and (\<lambda>s. cur_thread s \<noteq> idle_thread s) and
               (\<lambda>s. bound_yt_tcb_at ((=) None) (cur_thread s) s) and
               (\<lambda>s. sc_yf_sc_at ((=) None) scp s) and
               (\<lambda>s. sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scp s) and
               (\<lambda>s. ex_nonz_cap_to (cur_thread s) s) and
               ex_nonz_cap_to scp", rotated])
   apply (wpsimp wp: complete_yield_to_invs hoare_drop_imps complete_yield_to_sc_yf_sc_at_None
          | wps)+
   apply (clarsimp simp: obj_at_def sc_at_pred_n_def)
  apply (clarsimp simp: sc_at_pred_n_eq_commute)
  apply (wpsimp simp: invs_def valid_state_def valid_pspace_def get_sc_obj_ref_def
           split_del: if_split
                  wp: valid_irq_node_typ hoare_vcg_if_lift2 thread_get_inv hoare_drop_imp
                      valid_ioports_lift update_sched_context_valid_idle)
  apply (clarsimp cong: conj_cong)
  apply (intro conjI; clarsimp simp: cur_tcb_def)
    apply (clarsimp simp: sc_at_pred_n_def obj_at_def is_sc_obj_def)
    apply (fastforce dest!: valid_objs_valid_sched_context_size)
   apply (erule delta_sym_refs)
    apply (clarsimp split: if_splits)
    apply (clarsimp simp: sc_at_pred_n_def obj_at_def pred_tcb_at_def is_sc_obj_def)
   apply (clarsimp split: if_splits)
     apply (clarsimp simp: sc_at_pred_n_def obj_at_def pred_tcb_at_def is_sc_obj_def)
    apply (clarsimp simp: obj_at_def pred_tcb_at_def state_refs_of_def refs_of_def get_refs_def
                   split: option.splits)
   apply (clarsimp simp: sc_at_pred_n_def obj_at_def state_refs_of_def refs_of_def get_refs_def
                  split: option.splits)
  apply (clarsimp simp: sc_at_pred_n_def obj_at_def in_state_refs_of_iff pred_tcb_at_def
                        refs_of_simps get_refs_def2)
  apply (clarsimp dest!: idle_sc_no_ex_cap)
  done

text \<open>valid invocation definitions\<close>
primrec
  valid_sched_context_inv :: "sched_context_invocation \<Rightarrow> 'z::state_ext state \<Rightarrow> bool"
where
    "valid_sched_context_inv (InvokeSchedContextConsumed scptr args)
     = (sc_at scptr and ex_nonz_cap_to scptr and case_option \<top> in_user_frame args)"
  | "valid_sched_context_inv (InvokeSchedContextBind scptr cap)
     = (ex_nonz_cap_to scptr and valid_cap cap and
          (case cap of ThreadCap t \<Rightarrow>
                 bound_sc_tcb_at ((=) None) t and ex_nonz_cap_to t
                 and sc_tcb_sc_at ((=) None) scptr
                 and (\<lambda>s. st_tcb_at (ipc_queued_thread_state) t s
                          \<longrightarrow> sc_at_pred (sc_released (cur_time s)) scptr s)
             | NotificationCap n _ _ \<Rightarrow>
                 obj_at (\<lambda>ko. \<exists>ntfn. ko = Notification ntfn \<and> ntfn_sc ntfn = None) n
                 and ex_nonz_cap_to n  and sc_ntfn_sc_at ((=) None) scptr
             | _ \<Rightarrow> \<lambda>_. False))"
  | "valid_sched_context_inv (InvokeSchedContextUnbindObject scptr cap)
     = (ex_nonz_cap_to scptr and valid_cap cap and
          (case cap of ThreadCap t \<Rightarrow>
                   ex_nonz_cap_to t and sc_tcb_sc_at (\<lambda>tcb. tcb = (Some t)) scptr and (\<lambda>s. t \<noteq> cur_thread s)
             | NotificationCap n _ _ \<Rightarrow>
                   ex_nonz_cap_to n and sc_ntfn_sc_at (\<lambda>ntfn. ntfn = (Some n)) scptr
             | _ \<Rightarrow> \<lambda>_. False))"
  | "valid_sched_context_inv (InvokeSchedContextUnbind scptr)
     = (sc_at scptr and ex_nonz_cap_to scptr)"
  | "valid_sched_context_inv (InvokeSchedContextYieldTo scptr args)
     = (\<lambda>s. ex_nonz_cap_to scptr s
            \<and> bound_yt_tcb_at ((=) None) (cur_thread s) s
            \<and> case_option \<top> in_user_frame args s
            \<and> sc_tcb_sc_at (\<lambda>sctcb. \<exists>t. sctcb = Some t \<and> t \<noteq> cur_thread s) scptr s)"

definition
  valid_refills_number :: "nat \<Rightarrow> nat \<Rightarrow> bool"
where
  "valid_refills_number mrefills n \<equiv> mrefills \<le> max_num_refills (min_sched_context_bits + n)"

primrec
  valid_sched_control_inv :: "sched_control_invocation \<Rightarrow> 'z::state_ext state \<Rightarrow> bool"
where
    "valid_sched_control_inv (InvokeSchedControlConfigureFlags scptr budget period mrefills badge flags)
     = (obj_at (\<lambda>ko. \<exists>sc n. ko = SchedContext sc n \<and> valid_refills_number mrefills n) scptr
        and ex_nonz_cap_to scptr and K (MIN_REFILLS \<le> mrefills) \<comment> \<open>mrefills = MIN_REFILLS + extra_refills\<close>
        and K (budget \<le> MAX_PERIOD \<and> budget \<ge> MIN_BUDGET)
        and K (period \<le> MAX_PERIOD \<and> budget \<ge> MIN_BUDGET)
        and K (budget \<le> period))"


text \<open>refill invariant proofs\<close>  \<comment> \<open>FIXME move? Sporadic_AI?\<close>

(* FIXME: move refills material into DetSched files, as much as is possible *)

definition valid_refill_amount :: "obj_ref \<Rightarrow> 'z::state_ext state \<Rightarrow> bool"
where
  "valid_refill_amount scptr =
     (obj_at (\<lambda>ko. \<exists>sc n. ko= SchedContext sc n
      \<and> refills_sum (sc_refills sc) = sc_budget sc) scptr)"

definition
  no_overflow :: "refill list \<Rightarrow> bool"
where
  "no_overflow refills \<equiv>
      \<forall>refill \<in> set refills. unat (r_time refill) + unat (r_amount refill)
                            \<le> unat (max_word :: time)"

lemma no_overflow_sublist:
  "\<lbrakk>no_overflow list; sublist new_list list\<rbrakk> \<Longrightarrow> no_overflow new_list"
  by (clarsimp simp: sublist_def no_overflow_def)

lemma no_overflow_tail:
  "no_overflow (a # list) \<Longrightarrow> no_overflow list"
  by (force simp: no_overflow_def)

definition
  ordered_disjoint :: "refill list \<Rightarrow> bool"
where
  "ordered_disjoint refills \<equiv>
      \<forall>n < (length refills - Suc 0).
        unat (r_time (refills ! n)) + unat (r_amount (refills ! n))
          \<le> unat (r_time (refills ! (Suc n)))"

lemma ordered_disjoint_sublist:
  "\<lbrakk>ordered_disjoint list; sublist new_list list\<rbrakk> \<Longrightarrow> ordered_disjoint new_list"
  apply (simp add: sublist_def ordered_disjoint_def)
  apply clarsimp
  apply (subgoal_tac "new_list ! n = (ps @ new_list @ ss) ! (n + length ps)")
   apply (subgoal_tac "new_list ! Suc n = (ps @ new_list @ ss) ! Suc (n + length ps)")
    apply clarsimp
   apply (fastforce simp: nth_append)+
  done

lemma ordered_disjoint_tail:
  "ordered_disjoint (a # list) \<Longrightarrow> ordered_disjoint list"
  apply (clarsimp simp: ordered_disjoint_def)
  apply (drule_tac x="Suc n" in spec)
  by clarsimp

lemma ordered_disjoint_non_adjacent:
  "\<lbrakk>ordered_disjoint refills;
    k < length refills;
    l < length refills;
    k < l\<rbrakk>
   \<Longrightarrow> unat (r_time (refills ! k)) + unat (r_amount (refills ! k)) \<le> unat (r_time (refills ! l))"
  apply (induct refills arbitrary: k l rule: length_induct)
  apply (case_tac xs)
   apply simp
  apply (rename_tac a list)
  apply simp
  apply (drule_tac x=list in spec)
  apply clarsimp
  apply (elim impE; (clarsimp simp: no_overflow_tail ordered_disjoint_tail)?)
  apply (case_tac "k=0")
   apply simp
   apply (case_tac "l=1")
    apply (fastforce simp: ordered_disjoint_def)
   apply (rule_tac y="unat (r_time (list ! 0)) + unat (r_amount (list ! 0))" in order_trans)
    apply (rule_tac y="unat (r_time (list ! 0))" in order_trans)
    apply (fastforce simp: ordered_disjoint_def)+
  done

lemma ordered_disjoint_no_overflow_implies_sorted:
  "\<lbrakk>ordered_disjoint refills; no_overflow refills; k < length refills; l < length refills; k \<le> l\<rbrakk>
   \<Longrightarrow> unat (r_time (refills ! k)) \<le> unat (r_time (refills ! l))"
  apply (case_tac "k = l", simp)
  by (frule ordered_disjoint_non_adjacent[where refills=refills and k=k and l=l]; clarsimp)

lemma ordered_disjoint_last:
  "\<lbrakk>ordered_disjoint list; no_overflow list; list \<noteq> []\<rbrakk>
   \<Longrightarrow> \<forall>refill \<in> set list. unat (r_time refill) \<le> unat (r_time (last list))"
  apply (clarsimp simp: in_set_conv_nth)
  apply (subst last_conv_nth)
   apply fastforce
  apply (frule_tac k=i and l="length list - 1" in ordered_disjoint_no_overflow_implies_sorted; simp)
  done

(* FIXME maybe move? *)
lemma refills_sum_cons[simp]: "refills_sum (a#rs) =  r_amount a + refills_sum rs"
  by (clarsimp simp: refills_sum_def)

lemma refills_sum_append[simp]: "refills_sum (rs1 @ rs) =  refills_sum rs1 + refills_sum rs"
  by (clarsimp simp: refills_sum_def)

lemma refills_sum_nil[simp]: "refills_sum [] = 0" by (clarsimp simp: refills_sum_def)
(* end maybe move *)

(***** FIXME maybe move? *****)
(* unat addition *)
lemma sum_list_bounded_eq:
  "sum_list (map unat (ls :: time list)) = unat (budget :: time) \<Longrightarrow> sum_list (map unat ls) = unat (sum_list ls)"
  apply (induct ls arbitrary: budget, simp)
  apply clarsimp
  by (metis (no_types, opaque_lifting) le_add2 le_unat_uoi of_nat_add word_unat.Rep_inverse)

lemma sum_list_bounded_lt:
  "sum_list (map unat (ls :: time list)) < unat (budget :: time) \<Longrightarrow>sum_list (map unat ls) = unat (sum_list ls)"
  apply (induct ls arbitrary: budget, simp)
  apply clarsimp
  by (metis (mono_tags) add.commute add_lessD1 le_unat_uoi nat_less_le word_arith_nat_add)

lemma sum_list_bounded_le:
  "sum_list (map unat (ls :: time list)) \<le> unat (budget :: time) \<Longrightarrow>sum_list (map unat ls) = unat (sum_list ls)"
  apply (induct ls arbitrary: budget, simp)
  apply clarsimp
  by (metis add_leE le_unat_uoi word_arith_nat_add)

lemma "sum_list (map unat ls) = unat (sum_list ls) \<Longrightarrow> (\<forall>j::nat< length ls. \<forall>i::nat < j. unat (ls!j + ls!i) = unat (ls!j) + unat (ls!i))"
oops

(** end unat **)

(* FIXME: maybe move *)
(* FIXME: remove because unused? *)
lemma remove1_nth_rewrite:
  "(j::nat) < length ls \<Longrightarrow>
        set (remove1 (ls!j) ls)
                = set ((take j ls)
                          @ tl (drop j ls))"
  apply (subgoal_tac "remove1 (ls!j) ls = remove1 (ls!j) (take j ls @ (ls!j) # drop (j+1) ls)")
   apply (simp only: remove1_append)
   apply clarsimp
   apply (case_tac "(ls!j) \<in> set (take j ls)"; clarsimp)
proof -
  assume a1: "ls ! j \<in> set (take j ls)"
  have "tl (drop j ls) = drop (Suc j) ls"
    by (simp add: drop_Suc drop_tl)
  then show "insert (ls ! j) (set (remove1 (ls ! j) (take j ls)) \<union> set (drop (Suc j) ls)) = set (take j ls) \<union> set (tl (drop j ls))"
    using a1 split_list_first by fastforce
next
  assume a1: "ls ! j \<notin> set (take j ls)"
  have H1: "tl (drop j ls) = drop (Suc j) ls"
    by (simp add: drop_Suc drop_tl)
  then show "set (take j ls) \<union> set (drop (Suc j) ls) =
         set (take j ls) \<union> set (tl (drop j ls))" using H1 by auto
next
  assume a2: "j < length ls"
  show "remove1 (ls ! j) ls = remove1 (ls ! j) (take j ls @ ls ! j # drop (j + 1) ls)"
    by (simp add: Cons_nth_drop_Suc a2)
qed

(* FIXME: remove because unused? *)
lemma sum_list_elements_unat_sum':
  "\<lbrakk>Suc (Suc 0) \<le> length (ls::time list); sum_list (map unat ls) = unat (sum_list ls)\<rbrakk>
    \<Longrightarrow> \<forall>j < length ls. \<forall>i < j. unat (ls!i) + unat (ls!j) = unat (ls!i + ls!j)"
proof safe
  fix i j
  assume len: "Suc (Suc 0) \<le> length ls"
  assume sum_eq: "sum_list (map unat ls) = unat (sum_list ls)"
  assume H: "j < length ls" "i < j"
  have  "sum_list (map unat ls) =
          unat (ls!j) + unat (ls!i) + sum_list (map unat (remove1 (ls!i) (remove1 (ls!j) ls)))"
  proof -
    have setin_i': "ls!i \<in> set (remove1 (ls!j) ls)"
      proof
        have take_in: "(take j ls)!i \<in> set (take j ls)"
           using length_take nth_mem[where xs="take j ls" and n=i] H by clarsimp
        have take: "ls!i \<in> set (take j ls)"
          using nth_take[where xs=ls, OF H(2), symmetric] take_in by fastforce
        show ?this using take by simp
        next
        show "set (take j ls) \<subseteq> set (remove1 (ls!j) ls)"
         using remove1_nth_rewrite[where j=j and ls=ls] H by clarsimp
      qed
  have remove_j: "sum_list (map unat ls) =
            unat (ls!j) + sum_list (map unat (remove1 (ls!j) ls))"
    using H nth_mem[of j] sum_list_map_remove1 by fastforce
  also
  have remove_i: "sum_list (map unat (remove1 (ls!j) ls)) =
            unat (ls!i) + sum_list (map unat (remove1 (ls!i) (remove1 (ls!j) ls)))"
    using setin_i' sum_list_map_remove1 by fastforce
  then show ?thesis using remove_j by simp qed
  then have bounded: "unat (ls!j) + unat (ls!i) \<le> unat (sum_list ls)"
    using sum_eq by simp
  show " unat (ls!i) + unat (ls!j) = unat (ls!i + ls!j)"
    using sum_list_bounded_le[where ls="[ls!i, ls!j]" and budget="sum_list ls", simplified] bounded
    by fastforce
qed

(* FIXME: remove because unused? *)
lemmas sum_list_elements_unat_sum = sum_list_elements_unat_sum'[rule_format]

(***)

lemma MIN_BUDGET_no_overflow:
  "unat MIN_BUDGET = 2 * unat kernelWCET_ticks"
  apply (simp add: MIN_BUDGET_def kernelWCET_ticks_def)
  apply (rule replicate_no_overflow[where a="us_to_ticks kernelWCET_us" and n=2
                                      and upper_bound=max_word, simplified])
  apply (insert MIN_BUDGET_bound)
  apply (fastforce intro: order_trans[OF mult_left_mono, OF us_to_ticks_helper])
  done

\<comment> \<open>Function definitions and lemmas for showing that the unat sum of the r_amounts of a refill list
    does not overflow, and is equal to the budget of the scheduling context\<close>

definition
  refills_unat_sum :: "refill list \<Rightarrow> nat"
where
  "refills_unat_sum refills = sum_list (map unat (map r_amount refills))"

lemma refills_unat_sum_member_bound:
  "\<lbrakk>refills_unat_sum refills \<le> amount; refill \<in> set refills\<rbrakk> \<Longrightarrow> unat (r_amount refill) \<le> amount"
  apply (clarsimp simp: refills_unat_sum_def)
  apply (prop_tac "unat (r_amount refill) \<in> set (map unat (map r_amount refills))")
   apply fastforce
  apply (fastforce dest!: member_le_sum_list)
  done

lemma refills_unat_sum_cons:
  "refills_unat_sum (a # b) = unat (r_amount a) + refills_unat_sum b"
  by (clarsimp simp: refills_unat_sum_def)

lemma refills_unat_sum_length_one[simp]:
  "refills_unat_sum [a] = unat (r_amount a)"
  by (clarsimp simp: refills_unat_sum_def)

lemma refills_unat_sum_append:
  "refills_unat_sum (a @ b) = refills_unat_sum a + refills_unat_sum b"
  by (clarsimp simp: refills_unat_sum_def)

fun
  refill_list_to_intervals :: "refill list \<Rightarrow> (nat set) list"
where
  "refill_list_to_intervals [] = []"
| "refill_list_to_intervals (r # rs) = [{unat (r_time r) ..< unat (r_time r) + unat (r_amount r)}]
                                        @ (refill_list_to_intervals rs)"

lemma refill_list_to_intervals_length:
  "length (refill_list_to_intervals refills) = length refills"
  by (induction refills; simp)

lemma refill_list_to_intervals_index:
  "l < length refills \<Longrightarrow>
   (refill_list_to_intervals refills) ! l
   = {unat (r_time (refills ! l)) ..< unat (r_time (refills ! l)) + unat (r_amount (refills ! l))}"
  apply (induct refills arbitrary: l rule: length_induct)
  apply (rename_tac xs l)
  apply (case_tac xs; clarsimp?)
  apply (case_tac "l=0"; simp)
  done

lemma refill_list_to_intervals_index_nonempty_imp_r_amount_nonzero:
  "\<lbrakk>l < length refills; (refill_list_to_intervals refills) ! l \<noteq> {}\<rbrakk>
   \<Longrightarrow> unat (r_amount (refills ! l)) \<noteq> 0"
  by (fastforce dest: refill_list_to_intervals_index)

lemma max_closed_open_interval:
  "\<lbrakk>0 < b; {a ..< b} \<noteq> {}\<rbrakk> \<Longrightarrow> Max {a ..< b} = (b :: nat) - Suc 0"
  by (fastforce intro: linorder_class.Max_eqI)

lemma disjnt_max_min:
  "\<lbrakk>finite A; finite B; (Max A) < (Min B)\<rbrakk> \<Longrightarrow> A \<inter> B = {}"
  apply (rule ccontr)
  apply (frule int_not_emptyD)
  using Max_ge Min_le by (metis basic_trans_rules(23) leD)

lemma less_le_nonzero_helper:
  assumes "0 < a"
  shows "a \<le> b \<Longrightarrow> a - Suc 0 < b"
  using assms by linarith

lemma refill_list_to_intervals_finite:
  "l < length (refill_list_to_intervals refills) \<Longrightarrow> finite (refill_list_to_intervals refills ! l)"
  apply (induct refills arbitrary: l rule: length_induct)
  apply (rename_tac xs l)
  apply (case_tac xs, simp)
  by (case_tac "l=0") auto

lemma min_refill_list_to_intervals:
  "\<lbrakk>refills \<noteq> []; unat (r_amount (refills ! l)) \<noteq> 0;
    l < length (refill_list_to_intervals refills)\<rbrakk>
   \<Longrightarrow> Min (refill_list_to_intervals refills ! l) = unat (r_time (refills ! l))"
  apply (simp add: refill_list_to_intervals_length)
  apply (fastforce simp: refill_list_to_intervals_index unat_gt_0 Min_eq_iff)
  done

lemma disjoint_refill_list_to_intervals:
  "\<lbrakk>no_overflow refills; ordered_disjoint refills;
    l < length (refill_list_to_intervals refills);  k < l\<rbrakk>
   \<Longrightarrow> disjnt (refill_list_to_intervals refills ! k) (refill_list_to_intervals refills ! l)"
  apply (case_tac "refill_list_to_intervals refills ! k = {}"; clarsimp?)
  apply (case_tac "refill_list_to_intervals refills ! l = {}"; clarsimp?)
  apply (simp add: refill_list_to_intervals_length)
  apply (subst refill_list_to_intervals_index; fastforce?)+
  apply (simp only: disjnt_def)
  apply (rule disjnt_max_min; fastforce?)
  apply (frule_tac k=k and l=l in ordered_disjoint_non_adjacent; fastforce?)
  apply (simp add: refill_list_to_intervals_index_nonempty_imp_r_amount_nonzero)
  done

lemma refills_sum_unat_intervals:
  "refills_unat_sum refills = sum_list (map card (refill_list_to_intervals refills))"
  apply (induct refills rule: length_induct)
  by (case_tac xs; simp add: refills_unat_sum_def)

fun
  refill_list_to_subset :: "refill list \<Rightarrow> nat set"
where
  "refill_list_to_subset [] = {}"
| "refill_list_to_subset (r # rs) = {unat (r_time r) ..< unat (r_time r) + unat (r_amount r)}
                                    \<union> (refill_list_to_subset rs)"

lemma refill_list_to_subset_empty_imp_all_r_amounts_zero:
  "refill_list_to_subset refills = {} \<Longrightarrow> \<forall>refill \<in> set refills. r_amount refill = 0"
  apply (induct refills rule: length_induct)
  apply (rename_tac xs)
  apply (case_tac xs; clarsimp?)
  using unat_eq_0 by blast

lemma all_r_amounts_zero_imp_card_zero:
  "\<lbrakk>\<forall>refill \<in> set refills. r_amount refill = 0; l < length refills\<rbrakk>
   \<Longrightarrow> card ((refill_list_to_intervals refills)! l) = 0"
  apply (induct refills rule: length_induct)
  apply (rename_tac xs)
  apply (case_tac xs; clarsimp?)
  apply (case_tac "l=0"; clarsimp?)
  apply (fastforce simp: refill_list_to_intervals_index)
  done

lemma no_overflow_refill_list_to_subset_finite:
  "no_overflow refills \<Longrightarrow> finite (refill_list_to_subset refills)"
  apply (induct refills rule: length_induct)
  apply (rename_tac xs)
  apply (case_tac xs; fastforce dest: no_overflow_tail)
  done

lemma min_refill_list_to_subset:
  "\<lbrakk>refills \<noteq> [];
    no_overflow refills;
    ordered_disjoint refills;
    refill_list_to_subset refills \<noteq> {}\<rbrakk>
   \<Longrightarrow> Min (refill_list_to_subset refills) \<ge> unat (r_time (hd refills))"
  apply (induct refills rule: length_induct)
  apply (rename_tac xs)
  apply (case_tac xs)
   apply simp
  apply simp
  apply (frule no_overflow_tail)
  apply (frule ordered_disjoint_tail)
  apply (rename_tac a list)
  apply (case_tac "refill_list_to_subset list = {}"; clarsimp?)
  apply (case_tac "unat (r_amount a) = 0")
   apply clarsimp
   apply (rule_tac j="unat (r_time (hd list))" in le_trans)
    apply (clarsimp simp: ordered_disjoint_def)
    apply (metis Groups.add_ac(2) add_leD2 hd_conv_nth length_greater_0_conv nth_Cons_0
                 refill_list_to_subset.simps(1))
   apply fastforce
  apply (subst Min_Un; fastforce?)
   using no_overflow_refill_list_to_subset_finite apply presburger
  apply (prop_tac "Min {unat (r_time a)..<unat (r_time a) + unat (r_amount a)} = unat (r_time a)")
   apply (subst Min_eq_iff; fastforce?)
  apply (drule_tac x=list in spec)
  apply (elim impE; fastforce?)
  apply (clarsimp simp: ordered_disjoint_def)
  apply (rule_tac j="unat (r_time (hd list))" in le_trans; fastforce?)
  apply (metis (no_types, opaque_lifting) add.commute hd_conv_nth le_trans
               length_greater_0_conv nat_iffs(2) nth_Cons_0 refill_list_to_subset.simps(1))
  done

lemma disjoint_interval_list_implies_sum_is_bounded:
  "\<lbrakk>no_overflow refills; ordered_disjoint refills\<rbrakk>
   \<Longrightarrow> sum_list (map card (refill_list_to_intervals refills))
       = card (refill_list_to_subset refills)"
  apply (induct refills rule: length_induct)
  apply (rename_tac xs)
  apply (case_tac xs)
   apply simp
  apply simp
  apply (rename_tac a list)
  apply (frule no_overflow_tail)
  apply (frule ordered_disjoint_tail)
  apply (case_tac "r_amount a = 0"; clarsimp?)
  apply (case_tac "refill_list_to_subset list = {}"; clarsimp?)
  apply (prop_tac "Max {unat (r_time a)..<unat (r_time a) + unat (r_amount a)}
                   = unat (r_time a) + unat (r_amount a) - Suc 0")
   apply (rule max_closed_open_interval; simp add: unat_gt_0)
  apply (subst card_Un_disjoint; fastforce?)
   apply (rule no_overflow_refill_list_to_subset_finite)
   apply (fastforce dest: no_overflow_tail)
  apply (rule disjnt_max_min; fastforce?)
   apply (fastforce dest: no_overflow_tail
                   intro: no_overflow_refill_list_to_subset_finite
                    simp: unat_gt_0)
  apply (simp add: unat_gt_0)
  apply (subst less_le_nonzero_helper; fastforce?)
   apply (simp add: unat_gt_0)
  apply (rule_tac j="unat (r_time (hd list))" in le_trans)
   apply (clarsimp simp: ordered_disjoint_def)
   apply (metis hd_conv_nth length_greater_0_conv nth_Cons_0 refill_list_to_subset.simps(1))
  apply (rule min_refill_list_to_subset; fastforce?)
  done

(* FIXME RT: move *)
lemma max_union:
  "\<lbrakk>finite A; finite B; B \<noteq> {}; Max A < Min B\<rbrakk>
   \<Longrightarrow> Max (A \<union> B) = Max B"
  apply (subst eq_Max_iff; blast?)
  apply (intro conjI)
   apply (metis (no_types, lifting) Max_Un Max_gr_iff Max_in Min_gr_iff UnE Un_empty
                  dual_order.strict_implies_not_eq finite_UnI max.strict_coboundedI2 notemptyI)
  by simp

lemma no_overflow_implies_refill_list_to_subset_max_bounded:
  "\<lbrakk>refills \<noteq> []; no_overflow refills; ordered_disjoint refills;
    refill_list_to_subset refills \<noteq> {}\<rbrakk>
   \<Longrightarrow> Max (refill_list_to_subset refills) \<le> unat (max_word :: time)"
  apply (induct refills rule: length_induct)
  apply (rename_tac xs)
  apply (case_tac xs)
   apply simp
  apply (rename_tac a list)
  apply simp
  apply (frule no_overflow_tail)
  apply (frule ordered_disjoint_tail)
  apply (case_tac "refill_list_to_subset list = {}"; clarsimp?)
  apply (clarsimp simp: no_overflow_def)
  apply (case_tac "unat (r_amount a) = 0"; fastforce?)
  apply (subst max_union; fastforce?)
   apply (rule no_overflow_refill_list_to_subset_finite)
   apply (fastforce dest: no_overflow_tail)
  apply (subst max_closed_open_interval; fastforce?)
  apply (subst less_le_nonzero_helper; fastforce?)
  apply (rule_tac j="unat (r_time (hd list))" in le_trans)
   apply (clarsimp simp: ordered_disjoint_def)
   apply (metis hd_conv_nth length_greater_0_conv nth_Cons_0 refill_list_to_subset.simps(1))
  apply (rule min_refill_list_to_subset; fastforce?)
  done

lemma no_overflow_implies_refill_list_to_subset_card_bounded:
  "\<lbrakk>refills \<noteq> []; no_overflow refills; ordered_disjoint refills\<rbrakk>
   \<Longrightarrow> card (refill_list_to_subset refills) \<le> Suc (unat (max_word :: time))"
  apply (case_tac "refill_list_to_subset refills = {}"; clarsimp?)
  apply (frule no_overflow_implies_refill_list_to_subset_max_bounded; fastforce?)
  apply (rule subset_eq_atLeast0_lessThan_card)
  apply (clarsimp simp: atLeastLessThanSuc_atLeastAtMost)
  apply (rule_tac y="Max (refill_list_to_subset refills)" in order_trans)
   apply (rule Max.coboundedI)
    apply (rule no_overflow_refill_list_to_subset_finite)
    by blast+

lemma no_overflow_ordered_disjoint_implies_refills_sum_unat_no_overflow:
  "\<lbrakk>refills \<noteq> [];
    no_overflow refills;
    ordered_disjoint refills\<rbrakk>
   \<Longrightarrow> refills_unat_sum refills \<le> Suc (unat max_time)"
  apply (subst refills_sum_unat_intervals)
  apply (subst disjoint_interval_list_implies_sum_is_bounded; fastforce?)
   using disjoint_refill_list_to_intervals
  apply (simp add: refill_list_to_intervals_length disjoint_refill_list_to_intervals)
  apply (rule no_overflow_implies_refill_list_to_subset_card_bounded)
  by blast+

lemma sum_list_helper:
  "sum_list (map card (refill_list_to_intervals refills))
   = refills_unat_sum refills"
  apply (induction refills rule: length_induct)
  by (case_tac xs; simp add: refills_unat_sum_def)

lemma unat_sum_max_word:
  fixes w :: "'a::len word"
  shows "unat w + unat v = Suc (unat (max_word :: 'a word)) \<Longrightarrow> w + v = 0"
  by (metis arith_special(10) plus_1_eq_Suc unsigned_1 word_arith_nat_add)

lemma unat_sum_list_of_words:
  fixes list :: "'a::len word list"
  shows " unat (sum_list list) = (sum_list (map unat list)) mod 2 ^ LENGTH('a)"
  apply (induct list rule: length_induct)
  apply (case_tac xs, simp)
  apply (drule_tac x=list in spec)
  apply simp
  by (metis rdmods(5) unat_word_ariths(1))

lemma sum_exact_overflow:
  "sum_list (map unat (list :: time list)) = Suc (unat (max_word :: time)) \<Longrightarrow> sum_list list = 0"
  apply (induct list rule: length_induct)
   apply (case_tac xs)
   apply simp
  apply (drule_tac x=list in spec)
  apply simp
  using unat_sum_list_of_words
  by (metis (mono_tags, opaque_lifting) arith_special(10) list.map(2) plus_1_eq_Suc sum_list_simps(2)
                                        unat_word_ariths(1) unsigned_1 unsigned_eq_0_iff)

lemma exactly_max_word_plus_one_implies_unat_refills_sum_is_zero:
  "\<lbrakk>no_overflow refills;
    ordered_disjoint refills;
    refill_list_to_subset refills = {0..unat (max_word :: time)}\<rbrakk>
   \<Longrightarrow> unat (refills_sum refills) = 0"
  supply map_map[simp del]
  apply (simp add: refills_sum_def word_le_nat_alt)
  apply (subgoal_tac "card (refill_list_to_subset refills) = Suc (unat max_word)")
   prefer 2
   apply simp
  apply (frule disjoint_interval_list_implies_sum_is_bounded; assumption?)
  apply (fastforce simp: sum_list_helper sum_exact_overflow refills_unat_sum_def)+
  done

lemma max_interval_helper:
  "\<lbrakk>A \<noteq> {}; finite A; card A = Suc b; Max A \<le> b\<rbrakk> \<Longrightarrow> A = {0..b}"
  apply (subst set_eq_subset)
  apply (intro conjI)
   apply (rule ccontr)
   apply clarsimp
  apply (rule ccontr)
  apply clarsimp
  apply (induct b)
   apply fast
  apply (rule ccontr)
  apply (subgoal_tac "A \<subset> {0..Suc b}")
   apply (subgoal_tac "card A < card {0..Suc b}")
    apply fastforce
   using psubset_card_mono apply blast
  apply (rule ccontr)
  using subset_not_subset_eq by force

lemma no_overflow_ordered_disjoint_non_zero_refills_implies_card_not_equal_to_suc_max_word:
  "\<lbrakk>refills \<noteq> [];
    no_overflow refills;
    ordered_disjoint refills;
    MIN_BUDGET \<le> refills_sum refills\<rbrakk>
   \<Longrightarrow> \<not>card (refill_list_to_subset refills) = Suc (unat (max_word :: time))"
  apply (rule ccontr)
  apply simp
  apply (frule exactly_max_word_plus_one_implies_unat_refills_sum_is_zero; assumption?)
   apply (rule max_interval_helper; fastforce?)
    apply (erule no_overflow_refill_list_to_subset_finite)
   apply (rule no_overflow_implies_refill_list_to_subset_max_bounded; fastforce?)
  using MIN_BUDGET_pos by (simp add: unat_eq_zero)

lemma unat_sum_list_at_most_unat_max_word:
  "\<lbrakk>refills \<noteq> [];
    no_overflow refills;
    ordered_disjoint refills;
    MIN_BUDGET \<le> refills_sum refills\<rbrakk>
   \<Longrightarrow> refills_unat_sum refills \<le> unat max_time"
  supply map_map[simp del]
  apply (frule no_overflow_ordered_disjoint_implies_refills_sum_unat_no_overflow; assumption?)
  apply (frule no_overflow_ordered_disjoint_non_zero_refills_implies_card_not_equal_to_suc_max_word
         ; assumption?)
  apply (subst sum_list_helper[symmetric])
  apply (subst disjoint_interval_list_implies_sum_is_bounded; assumption?)
  apply (subgoal_tac "refills_unat_sum refills = card (refill_list_to_subset refills)")
   apply linarith
  apply (subst sum_list_helper[symmetric])
  apply (subst disjoint_interval_list_implies_sum_is_bounded)
     apply simp+
  done

lemma unat_sum_list_equals_budget:
  "\<lbrakk>refills \<noteq> [];
    no_overflow refills;
    ordered_disjoint refills;
    MIN_BUDGET \<le> refills_sum refills\<rbrakk>
   \<Longrightarrow> refills_unat_sum refills = unat (refills_sum refills)"
  supply map_map[simp del]
  apply (frule unat_sum_list_at_most_unat_max_word; assumption?)
  by (fastforce simp: refills_sum_def refills_unat_sum_def intro: sum_list_bounded_le)

(* FIXME move *)
lemma sorted_wrt_last_append:
  assumes trans: "\<And>x y z. P x y \<Longrightarrow> P y z \<Longrightarrow> P x z"
  shows "\<lbrakk>sorted_wrt P (ls::'a list); P (last ls) new; ls \<noteq> []\<rbrakk> \<Longrightarrow> sorted_wrt P (ls @ [new])"
  apply (induct ls, simp)
  apply (clarsimp split: if_split_asm)
  by (drule_tac x="last ls" in bspec, simp) (fastforce intro: trans)

lemma refill_word_proof_helper:
  "\<lbrakk>unat (head_time :: time) + unat period \<le> unat (max_word :: time);
    larger \<le> period;
    smaller \<le> larger\<rbrakk>
    \<Longrightarrow> unat (head_time + period - (larger - smaller))
        = unat head_time + unat period - unat larger + unat smaller"
  apply (subgoal_tac "unat (head_time + period) = unat head_time + unat period")
   apply (subgoal_tac "unat (head_time + period - (larger - smaller))
                       = unat (head_time + period) - unat (larger - smaller)")
    apply (simp add: unat_sub)
    apply (metis word_le_nat_alt Nat.diff_add_assoc2 Nat.diff_diff_right unat_plus_simple
                 word_le_plus_either)
   apply (simp add: unat_plus_simple unat_sub word_le_imp_diff_le
                    word_le_plus_either word_le_nat_alt)
  using unat_add_lem'' by blast

lemma ordered_disjoint_append:
  "\<lbrakk>left \<noteq> [] \<longrightarrow> ordered_disjoint left;
    right \<noteq> [] \<longrightarrow> ordered_disjoint right;
    left \<noteq> [] \<and> right \<noteq> [] \<longrightarrow> unat (r_time (last left)) + unat (r_amount (last left))
                                 \<le> unat (r_time (hd right));
    left @ right = result\<rbrakk>
   \<Longrightarrow> ordered_disjoint result"
  apply (clarsimp simp: ordered_disjoint_def)
  apply (case_tac left, clarsimp; case_tac right; fastforce?)
    apply (subst nth_append not_less)+
  apply (clarsimp split: if_splits)
  using last_conv_nth by (metis less_antisym list_exhaust_size_eq0 nth_Cons')

lemma no_overflow_append:
  "\<lbrakk>no_overflow left; no_overflow right; left @ right = result\<rbrakk>
   \<Longrightarrow> no_overflow result"
  by (fastforce simp: no_overflow_def)

(* FIXME: maybe move? *)
lemma last_butlast_list:
  "butlast list \<noteq> []
   \<Longrightarrow> last (butlast list) = list ! (length list - Suc (Suc 0))"
  by (metis last_conv_nth One_nat_def butlast_conv_take diff_Suc_eq_diff_pred le_add_diff_inverse2
            le_simps(3) length_butlast less_add_one list_exhaust_size_eq0 nth_take zero_order(5))

lemma butlast_nonempty_length:
  "butlast list \<noteq> [] \<Longrightarrow> Suc 0 < length list"
  by (cases list, simp, force)

(* FIXME remove *)
abbreviation "sc_at_period \<equiv> sc_period_sc_at"

lemmas sc_at_period_def = sc_period_sc_at_def

lemma tail_nonempty_length:
  "tl list \<noteq> [] \<Longrightarrow> Suc 0 < length list"
  by (cases list, simp, simp)

lemma set_refills_sc_at_period[wp]:
  "\<lbrace>sc_at_period P p\<rbrace> set_refills sc_ptr refills \<lbrace>\<lambda>_. sc_at_period P p\<rbrace>"
  apply (wpsimp simp: set_refills_def update_sched_context_def set_object_def
             wp: get_object_wp)
  by (clarsimp simp: sc_at_period_def obj_at_def)

lemma set_refills_sc_at_period'[wp]:
  "\<lbrace>\<lambda>s. sc_at_period P (cur_sc s) s\<rbrace> set_refills sc_ptr refills \<lbrace>\<lambda>_ s. sc_at_period P (cur_sc s) s\<rbrace>"
  apply (wpsimp simp: set_refills_def update_sched_context_def set_object_def
             wp: get_object_wp)
  by (clarsimp simp: sc_at_period_def obj_at_def)

lemma non_empty_tail_length:
  "tl list \<noteq> [] \<Longrightarrow> Suc 0 \<le> length list"
  using le0 list.sel(2) not_less_eq_eq by blast

text \<open>invocation related lemmas\<close>

lemma sched_context_bind_tcb_typ_at[wp]:
  "\<lbrace>\<lambda>s. P (typ_at T p s)\<rbrace>
      sched_context_bind_tcb sc tcb \<lbrace>\<lambda>rv s. P (typ_at T p s)\<rbrace>"
  by (wpsimp simp: sched_context_bind_tcb_def wp: hoare_drop_imps)

lemma sched_context_yield_to_typ_at[wp]:
  "\<lbrace>\<lambda>s. P (typ_at T p s)\<rbrace>
      sched_context_yield_to sc_ptr args \<lbrace>\<lambda>rv s. P (typ_at T p s)\<rbrace>"
  by (wpsimp simp: sched_context_yield_to_def wp: hoare_drop_imp hoare_vcg_if_lift2)

lemma invoke_sched_context_typ_at[wp]:
  "\<lbrace>\<lambda>s. P (typ_at T p s)\<rbrace>
     invoke_sched_context i
   \<lbrace>\<lambda>rv s. P (typ_at T p s)\<rbrace>"
  by (cases i;
      wpsimp wp: dxo_wp_weak mapM_x_wp get_sched_context_wp
       simp: invoke_sched_context_def sched_context_bind_ntfn_def)

context notes if_weak_cong[cong del] begin
crunch charge_budget
 for typ_at[wp]: "\<lambda>s. P (typ_at T p s)"
  (wp: hoare_drop_imp maybeM_inv simp: Let_def)
end

lemma check_budget_typ_at[wp]:
  "\<lbrace>\<lambda>s. P (typ_at T p s)\<rbrace> check_budget \<lbrace>\<lambda>rv s. P (typ_at T p s)\<rbrace>"
  by (wpsimp simp: check_budget_def split_del: if_split
            wp: hoare_vcg_if_lift2 hoare_drop_imp)

context notes if_weak_cong[cong del] begin

end

crunch invoke_sched_control_configure_flags
  for typ_at[wp]: "\<lambda>s. P (typ_at T p s)"
  (simp: crunch_simps)

lemma invoke_sched_context_tcb[wp]:
  "\<lbrace>tcb_at tptr\<rbrace> invoke_sched_context i \<lbrace>\<lambda>rv. tcb_at tptr\<rbrace>"
  by (simp add: tcb_at_typ invoke_sched_context_typ_at [where P=id, simplified])

lemma invoke_sched_control_tcb[wp]:
  "\<lbrace>tcb_at tptr\<rbrace> invoke_sched_control_configure_flags i \<lbrace>\<lambda>rv. tcb_at tptr\<rbrace>"
  by (simp add: tcb_at_typ invoke_sched_control_configure_flags_typ_at [where P=id, simplified])

lemma invoke_sched_context_invs[wp]:
  "\<lbrace>invs and valid_sched_context_inv i and ct_active\<rbrace> invoke_sched_context i \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (cases i;
         wpsimp simp: invoke_sched_context_def set_consumed_def valid_sched_context_inv_def
                  wp: sched_context_yield_to_invs)
    apply (clarsimp simp: obj_at_def sc_tcb_sc_at_def sc_ntfn_sc_at_def is_sc_obj_def is_tcb
                          valid_cap_def idle_no_ex_cap ct_in_state_def
                   split: cap.split_asm)+
   apply (frule invs_valid_global_refs,
          fastforce simp: invs_valid_objs idle_sc_no_ex_cap idle_no_ex_cap)
  apply (fastforce simp: invs_def valid_state_def valid_pspace_def live_def ct_in_state_def
                         obj_at_def pred_tcb_at_def valid_idle_def
                   dest: if_live_then_nonz_capD2)
  done

lemma shows
  update_sc_badge_valid_replies:
  "\<lbrace>valid_replies_pred P and (\<lambda>s. (\<exists>n. ko_at (SchedContext sc n) p s))\<rbrace>
   update_sched_context p (\<lambda>_. sc\<lparr>sc_badge := i \<rparr>)
   \<lbrace>\<lambda>rv. valid_replies_pred P\<rbrace>" and
  update_sc_sporadic_valid_replies:
  "\<lbrace>valid_replies_pred P and (\<lambda>s. (\<exists>n. ko_at (SchedContext sc n) p s))\<rbrace>
   update_sched_context p (\<lambda>_. sc\<lparr>sc_sporadic := f \<rparr>)
   \<lbrace>\<lambda>rv. valid_replies_pred P\<rbrace>"
  by (wpsimp wp: update_sched_context_wp,
      fastforce dest: ko_at_obj_congD)+

lemma update_sc_refills_period_refill_max_valid_replies:
  "\<lbrace>valid_replies_pred P and (\<lambda>s. (\<exists>n. ko_at (SchedContext sc n) p s))\<rbrace>
   update_sched_context p (\<lambda>_. sc\<lparr>sc_period := period, sc_refill_max := m, sc_refills := r, sc_budget := b\<rparr>)
   \<lbrace>\<lambda>rv. valid_replies_pred P\<rbrace>"
  by (wpsimp wp: update_sched_context_wp,
      fastforce dest: ko_at_obj_congD)

lemma update_sc_refills_valid_replies[wp]:
  "\<lbrace>valid_replies_pred P and (\<lambda>s. (\<exists>n. ko_at (SchedContext sc n) p s))\<rbrace>
   update_sched_context p (\<lambda>_. sc\<lparr>sc_refills := r\<rparr>)
   \<lbrace>\<lambda>rv. valid_replies_pred P\<rbrace>"
  by (wpsimp wp: update_sched_context_wp,
      fastforce dest: ko_at_obj_congD)

lemma shows
  update_sc_badge_cur_sc_tcb:
  "\<lbrace>\<lambda>s. cur_sc_tcb s \<and> (\<exists>n. ko_at (SchedContext sc n) p s)\<rbrace>
   update_sched_context p (\<lambda>_. sc\<lparr>sc_badge := i\<rparr>)
   \<lbrace>\<lambda>rv. cur_sc_tcb\<rbrace>" and
  update_sc_sporadic_cur_sc_tcb:
  "\<lbrace>\<lambda>s. cur_sc_tcb s \<and> (\<exists>n. ko_at (SchedContext sc n) p s)\<rbrace>
   update_sched_context p (\<lambda>_. sc\<lparr>sc_sporadic := f\<rparr>)
   \<lbrace>\<lambda>rv. cur_sc_tcb\<rbrace>"
  by (wpsimp simp: update_sched_context_def set_object_def get_object_def cur_sc_tcb_def
                   sc_tcb_sc_at_def obj_at_def)+

lemma update_sc_badge_invs:
  "\<lbrace>\<lambda>s. invs s \<and> p \<noteq> idle_sc_ptr \<and> (\<exists>n. ko_at (SchedContext sc n) p s)\<rbrace>
   update_sched_context p (\<lambda>_. sc\<lparr>sc_badge := i\<rparr>)
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (wpsimp simp: invs_def valid_state_def valid_pspace_def
                  wp: update_sched_context_valid_idle update_sc_badge_cur_sc_tcb
                      update_sc_badge_valid_replies)
  apply (auto simp: state_refs_of_def obj_at_def valid_obj_def live_def
             elim!: delta_sym_refs if_live_then_nonz_capD
             split: if_splits)
  done

lemma update_sc_sporadic_invs:
  "\<lbrace>\<lambda>s. invs s \<and> p \<noteq> idle_sc_ptr \<and> (\<exists>n. ko_at (SchedContext sc n) p s)\<rbrace>
   update_sched_context p (\<lambda>_. sc\<lparr>sc_sporadic := i\<rparr>)
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (wpsimp simp: invs_def valid_state_def valid_pspace_def
                  wp: update_sched_context_valid_idle update_sc_sporadic_cur_sc_tcb
                      update_sc_sporadic_valid_replies)
  apply (auto simp: state_refs_of_def obj_at_def valid_obj_def live_def
             elim!: delta_sym_refs if_live_then_nonz_capD
             split: if_splits)
  done

(* FIXME copied from Syscall_AI *)
lemma thread_set_cap_to:
  "(\<And>tcb. \<forall>(getF, v)\<in>ran tcb_cap_cases. getF (f tcb) = getF tcb)
  \<Longrightarrow> \<lbrace>ex_nonz_cap_to p\<rbrace> thread_set f tptr \<lbrace>\<lambda>_. ex_nonz_cap_to p\<rbrace>"
  apply (clarsimp simp add: ex_nonz_cap_to_def)
  apply (wpsimp wp: hoare_vcg_ex_lift thread_set_cte_wp_at_trivial)
  apply auto
  done

lemma thread_set_timeout_fault_valid_mdb[wp]:
  "\<lbrace>valid_mdb\<rbrace> thread_set (tcb_fault_update (\<lambda>_. Some (Timeout badge))) t \<lbrace>\<lambda>rv. valid_mdb\<rbrace>"
  apply (simp add: thread_set_def set_object_def get_object_def)
  apply (rule valid_mdb_lift)
    apply wp
    apply clarsimp
    apply (subst caps_of_state_after_update)
     apply (clarsimp simp: ran_tcb_cap_cases)
    apply simp
   apply (wp | simp)+
  done

lemma thread_set_timeout_fault_valid_irq_handlers[wp]:
  "\<lbrace>valid_irq_handlers\<rbrace> thread_set (tcb_fault_update (\<lambda>_. Some (Timeout badge))) t \<lbrace>\<lambda>rv. valid_irq_handlers\<rbrace>"
  apply (simp add: thread_set_def set_object_def get_object_def)
  apply (rule valid_irq_handlers_lift)
    apply wp
    apply clarsimp
    apply (subst caps_of_state_after_update)
     apply (clarsimp simp: ran_tcb_cap_cases)
    apply simp
   apply (wp | simp)+
  done

lemma send_fault_ipc_invs':
  assumes set_endpoint_Q[wp]: "\<And>a b.\<lbrace>Q\<rbrace> set_endpoint a b \<lbrace>\<lambda>_.Q\<rbrace>"
  assumes sts_Q[wp]: "\<And>a b. \<lbrace>Q\<rbrace> set_thread_state a b \<lbrace>\<lambda>_.Q\<rbrace>"
  assumes ext_Q[wp]: "\<And>a. \<lbrace>Q and valid_objs\<rbrace> possible_switch_to a \<lbrace>\<lambda>_.Q\<rbrace>"
  assumes do_ipc_transfer_Q[wp]: "\<And>a b c d e. \<lbrace>Q and valid_objs and valid_mdb\<rbrace>
                                               do_ipc_transfer a b c d e \<lbrace>\<lambda>_.Q\<rbrace>"
  assumes thread_set_Q[wp]: "\<And>a b. \<lbrace>Q\<rbrace> thread_set a b \<lbrace>\<lambda>_.Q\<rbrace>"
  assumes reply_push_Q[wp]: "\<And>a b c d. \<lbrace>Q\<rbrace> reply_push a b c d \<lbrace>\<lambda>_. Q\<rbrace>"
  assumes sched_context_donate_Q[wp]: "\<And>a b. \<lbrace>Q\<rbrace> sched_context_donate a b \<lbrace>\<lambda>_. Q\<rbrace>"
  assumes reply_unlink_tcb_Q[wp]: "\<And>t r. \<lbrace>Q\<rbrace> reply_unlink_tcb t r \<lbrace>\<lambda>_. Q\<rbrace>"
  assumes refill_unblock_check_Q[wp]: "\<And>scp. \<lbrace>Q\<rbrace> refill_unblock_check scp \<lbrace>\<lambda>_. Q\<rbrace>"
  notes si_invs''[wp] = si_invs'_fault[where Q=Q]
  shows
  "\<lbrace>invs and Q
    and st_tcb_at active tptr and ex_nonz_cap_to tptr and K (valid_fault fault)
    and (\<lambda>s. \<exists>n. caps_of_state s (tptr, tcb_cnode_index n) = Some cap)
    and K (valid_fault_handler cap) and (\<lambda>s. canDonate \<longrightarrow> bound_sc_tcb_at bound tptr s)\<rbrace>
   send_fault_ipc tptr cap fault canDonate
   \<lbrace>\<lambda>rv. invs and Q\<rbrace>"
  apply (cases "valid_fault fault"; simp)
  apply (clarsimp simp: send_fault_ipc_def)
  apply (wpsimp wp: test thread_set_invs_but_fault_tcbs
                    thread_set_no_change_tcb_state ex_nonz_cap_to_pres
                    thread_set_cte_wp_at_trivial
                    thread_set_no_change_tcb_sched_context
                    hoare_vcg_imp_lift gbn_wp
         | clarsimp simp: tcb_cap_cases_def
         | erule disjE)+
   apply (clarsimp simp: pred_tcb_at_def obj_at_def get_tcb_ko_at,
          subst (asm) caps_of_state_tcb_index_trans, erule get_tcb_rev,
          simp (no_asm) add: ex_nonz_cap_to_def cte_wp_at_cases2,
          rule exI, rule_tac x = "tcb_cnode_index n" in exI,
          force simp: obj_at_def tcb_cnode_map_def)+
  done

lemmas send_fault_ipc_invs[wp] = send_fault_ipc_invs'[where Q=\<top>,simplified hoare_TrueI, OF TrueI TrueI TrueI TrueI TrueI,simplified]

lemma handle_timeout_Timeout_invs:
  "\<lbrace>invs and st_tcb_at active tptr\<rbrace>
     handle_timeout tptr (Timeout badge)  \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (clarsimp simp: handle_timeout_def)
  apply (wpsimp wp: thread_set_invs_trivial send_fault_ipc_invs
              simp: handle_timeout_def ran_tcb_cap_cases
                    thread_set_def valid_fault_def)
  apply (case_tac "tcb_timeout_handler y"; clarsimp)
  apply (rule conjI)
   apply (clarsimp simp: pred_tcb_at_def obj_at_def dest!: get_tcb_SomeD)
   apply (drule invs_iflive)
   apply (drule (1) if_live_then_nonz_capD2)
    apply (fastforce simp: live_def)
   apply clarsimp
  apply (rule_tac P="\<exists>n. P n" and P'="P 4" and Q=Q and Q'=Q for P Q in conj_forward)
    apply (rule context_conjI)
     apply (clarsimp simp: caps_of_state_tcb_index_trans tcb_cnode_map_def)
    apply (auto simp: tcb_cap_slot_regular get_tcb_ko_at obj_at_def dest: tcb_cap_slot_regular)
  done

lemma end_timeslice_invs:
  "\<lbrace>\<lambda>s. invs s \<and> ct_active s\<rbrace>
      end_timeslice t \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (wpsimp simp: end_timeslice_def ct_in_state_def get_tcb_queue_def
          wp: handle_timeout_Timeout_invs hoare_drop_imp hoare_vcg_if_lift2)
  done

(* move to SchedContext_AI *)
lemma set_sc_refills_cur_sc_tcb[wp]:
  "\<lbrace>\<lambda>s. cur_sc_tcb s \<and> (\<exists>n. ko_at (SchedContext sc n) p s)\<rbrace>
   update_sched_context p (\<lambda>_. sc\<lparr>sc_refills := rs\<rparr>) \<lbrace>\<lambda>rv. cur_sc_tcb\<rbrace>"
  by (wpsimp simp: update_sched_context_def cur_sc_tcb_def sc_tcb_sc_at_def obj_at_def
               wp: set_object_wp get_object_wp)

lemma update_sc_refills_cur_sc_tcb[wp]:
  "\<lbrace>cur_sc_tcb\<rbrace> update_sched_context scp (sc_refills_update f) \<lbrace>\<lambda>rv. cur_sc_tcb\<rbrace>"
  by (wpsimp wp: update_sched_context_cur_sc_tcb_no_change)

lemma set_sc_refills_valid_idle:
  "\<lbrace>valid_idle and (\<lambda>s. (\<exists>n. ko_at (SchedContext sc n) p s))\<rbrace>
   update_sched_context p (\<lambda>_. sc\<lparr>sc_refills := r\<rparr>)
   \<lbrace>\<lambda>_. valid_idle\<rbrace>"
  by (wpsimp simp: update_sched_context_def set_object_def get_object_def valid_idle_def
                   pred_tcb_at_def obj_at_def)

lemma sched_context_refill_update_invs:
  "\<lbrace>\<lambda>s. invs s \<and> (\<exists>n. ko_at (SchedContext sc n) scp s)\<rbrace>
   update_sched_context scp (\<lambda>_. sc\<lparr>sc_refills := r0#rs\<rparr>)
   \<lbrace>\<lambda>_. invs\<rbrace>"
  apply (wpsimp simp: invs_def valid_state_def valid_pspace_def wp: set_sc_refills_valid_idle)
  apply (auto simp: state_refs_of_def obj_at_def valid_obj_def valid_sched_context_def live_def
                    live_sc_def
             elim!: delta_sym_refs if_live_then_nonz_capD
             split: if_splits)
  done

lemma update_sched_context_sc_refills_update_invs:
  "\<lbrace>\<lambda>s. invs s \<and> (\<forall>ls. ls \<noteq> [] \<longrightarrow> f ls \<noteq> [])\<rbrace>
   update_sched_context scp (sc_refills_update f)
   \<lbrace>\<lambda>_. invs\<rbrace>"
  by (wpsimp simp: invs_def valid_state_def valid_pspace_def valid_sched_context_def
               wp: update_sched_context_valid_objs_same valid_irq_node_typ
                   update_sched_context_refs_of_same)

lemma sc_consumed_add_valid_replies:
  "\<lbrace> valid_replies \<rbrace>
   update_sched_context scp (\<lambda>sc. sc\<lparr>sc_consumed := sc_consumed sc + consumed\<rparr>)
   \<lbrace> \<lambda>_. valid_replies \<rbrace>"
  by (wpsimp wp: update_sched_context_wp)

lemma sc_consumed_add_invs:
  "\<lbrace>\<lambda>s. invs s\<rbrace>
   update_sched_context scp (\<lambda>sc. sc\<lparr>sc_consumed := sc_consumed sc + consumed\<rparr>)
   \<lbrace>\<lambda>_. invs\<rbrace>"
  by (wpsimp simp: sc_consumed_update_eq[symmetric])

abbreviation active_sc_at :: "obj_ref \<Rightarrow> 'z::state_ext state \<Rightarrow> bool" where
  "active_sc_at \<equiv> obj_at (\<lambda>ko. \<exists>sc. (\<exists>n. ko = SchedContext sc n) \<and> sc_active sc)"

lemmas active_sc_at_def = obj_at_def

lemma set_refills_active_sc_at[wp]:
  "set_refills sc_ptr refills \<lbrace>\<lambda>s. P (active_sc_at sc_ptr s)\<rbrace>"
  apply (clarsimp simp: set_refills_def)
  apply (wpsimp wp: update_sched_context_wp)
  apply (clarsimp simp: active_sc_at_def)
  done

lemma refill_unblock_check_active_sc_at[wp]:
  "refill_unblock_check sc_ptr \<lbrace>\<lambda>s. Q (active_sc_at sc_ptr s)\<rbrace>"
  apply (clarsimp simp: refill_unblock_check_defs simp del: update_refill_hd_def)
  apply (wpsimp wp: set_refills_wp get_refills_wp whileLoop_valid_inv
              simp: update_refill_hd_rewrite update_sched_context_set_refills_rewrite active_sc_at_def)
  done

lemma refill_add_tail_invs[wp]:
  "refill_add_tail sc_ptr new \<lbrace>invs\<rbrace>"
  unfolding refill_add_tail_def
  by (wpsimp wp: update_sched_context_sc_refills_update_invs)

lemma refill_update_invs:
  "\<lbrace>\<lambda>s. invs s \<and> sc_ptr \<noteq> idle_sc_ptr\<rbrace>
   refill_update sc_ptr new_period new_budget new_max_refills
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  unfolding refill_update_def
  by (wpsimp wp: hoare_vcg_all_lift hoare_drop_imps set_sc_obj_ref_invs_no_change)

lemma refill_reset_rr_invs[wp]:
  "refill_reset_rr csc_ptr \<lbrace>invs\<rbrace>"
  unfolding refill_reset_rr_def update_refill_tl_def update_refill_hd_def set_refill_tl_def
            set_refill_hd_def
  by wpsimp

lemma charge_budget_invs[wp]:
  "\<lbrace>invs\<rbrace>
   charge_budget consumed canTimeout
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  supply if_split [split del]
  unfolding charge_budget_def is_round_robin_def
  apply clarsimp
  apply (rule bind_wp[OF _ gets_sp])
  apply (wpsimp wp: end_timeslice_invs assert_inv hoare_vcg_if_lift2 gts_wp is_schedulable_wp)
     apply (rule_tac Q'="\<lambda>_. invs" in hoare_strengthen_post[rotated])
      apply (clarsimp simp: ct_in_state_def runnable_eq pred_tcb_at_def obj_at_def schedulable_def
                     split: option.splits)
      apply (subgoal_tac "cur_tcb s")
       apply (clarsimp simp: get_tcb_def cur_tcb_def tcb_at_def is_tcb split: option.splits kernel_object.splits)
      apply (wpsimp wp: end_timeslice_invs assert_inv hoare_vcg_if_lift2 gts_wp
                        hoare_vcg_all_lift  sc_consumed_add_invs refill_budget_check_invs
                  simp: Let_def)+
  apply (frule invs_cur)
  apply (clarsimp simp: ct_in_state_def schedulable_def pred_tcb_at_def obj_at_def get_tcb_def
                        cur_tcb_def
                 split: kernel_object.splits if_splits)
  by (metis (no_types, lifting) option.case_eq_if runnable_eq)

lemma check_budget_invs[wp]:
  "\<lbrace>\<lambda>s. invs s\<rbrace> check_budget \<lbrace>\<lambda>rv. invs \<rbrace>"
  by (wpsimp simp: check_budget_def refill_size_def
               wp: get_refills_inv hoare_drop_imp get_sched_context_wp charge_budget_invs)

lemma tcb_sched_action_bound_sc[wp]:
  "\<lbrace>\<lambda>s. bound_sc_tcb_at bound (cur_thread s) s\<rbrace>
   tcb_sched_action action thread
   \<lbrace>\<lambda>rv s. bound_sc_tcb_at bound (cur_thread s) s\<rbrace>"
  by (wpsimp simp: tcb_sched_action_def set_tcb_queue_def get_tcb_queue_def
               wp: hoare_drop_imp hoare_vcg_all_lift)

lemma tcb_release_remove_bound_sc:
  "\<lbrace>\<lambda>s. bound_sc_tcb_at bound (cur_thread s) s\<rbrace>
   tcb_release_remove tcb_ptr
   \<lbrace>\<lambda>rv s. bound_sc_tcb_at bound (cur_thread s) s\<rbrace>"
  by (wpsimp simp: tcb_release_remove_def)

lemma
  shows update_sc_badge_cur_sc_tcb':
  "\<lbrace>cur_sc_tcb\<rbrace> update_sched_context p (sc_badge_update (\<lambda>_. badge)) \<lbrace>\<lambda>_. cur_sc_tcb\<rbrace>"
  and update_sc_sporadic_cur_sc_tcb':
  "\<lbrace>cur_sc_tcb\<rbrace> update_sched_context p (sc_sporadic_update (\<lambda>_. flag)) \<lbrace>\<lambda>_. cur_sc_tcb\<rbrace>"
  by (wpsimp simp: update_sched_context_def set_object_def get_object_def
                   cur_sc_tcb_def sc_tcb_sc_at_def obj_at_def)+

lemma
  shows update_sc_badge_invs':
  "\<lbrace>invs and K (p \<noteq> idle_sc_ptr)\<rbrace>
      update_sched_context p (sc_badge_update (\<lambda>_. badge)) \<lbrace>\<lambda>rv. invs\<rbrace>"
  and update_sc_sporadic_invs':
  "\<lbrace>invs and K (p \<noteq> idle_sc_ptr)\<rbrace>
      update_sched_context p (sc_sporadic_update (\<lambda>_. flag)) \<lbrace>\<lambda>rv. invs\<rbrace>"
  by (wpsimp simp: invs_def valid_state_def valid_pspace_def obj_at_def
                  wp: update_sched_context_valid_objs_same valid_irq_node_typ
                      update_sched_context_iflive_implies
                      update_sched_context_refs_of_same
                      update_sc_but_not_sc_replies_valid_replies_2
                      update_sched_context_valid_idle
                      update_sc_badge_cur_sc_tcb'
                      update_sc_sporadic_cur_sc_tcb'
            simp_del: fun_upd_apply)+

lemma set_sc_obj_ref_active:
  "(\<And>sc. \<lbrakk> p=p'; sc_active sc \<rbrakk> \<Longrightarrow> sc_active (f (\<lambda>_. x) sc)) \<Longrightarrow>
   set_sc_obj_ref f p x \<lbrace>active_sc_at p'\<rbrace>"
  unfolding update_sched_context_def
  by (wpsimp wp: set_object_wp get_object_wp simp: obj_at_def)

crunch commit_time
  for sc_active: "active_sc_at sc_ptr"
  (wp: set_sc_obj_ref_active whileLoop_valid_inv crunch_wps simp: crunch_simps)

lemma sc_badge_update_active[wp]:
  "set_sc_obj_ref sc_badge_update sc_ptr x \<lbrace>active_sc_at p'\<rbrace>"
  by (rule set_sc_obj_ref_active) simp

lemma sc_sporadic_update_active[wp]:
  "set_sc_obj_ref sc_sporadic_update sc_ptr x \<lbrace>active_sc_at p'\<rbrace>"
  by (rule set_sc_obj_ref_active) simp

crunch refill_new
  for st_tcb_at[wp]: "\<lambda>s. \<not> st_tcb_at P tcb_ptr s"
  (simp: crunch_simps wp: crunch_wps)

lemma invoke_sched_control_configure_flags_invs[wp]:
  "\<lbrace>\<lambda>s. invs s \<and> valid_sched_control_inv i s\<rbrace>
   invoke_sched_control_configure_flags i
   \<lbrace>\<lambda>rv. invs\<rbrace>"
  supply if_split[split del]
  apply (cases i)
  apply (rename_tac sc_ptr budget period mrefills badge flag)
  apply (clarsimp simp: invoke_sched_control_configure_flags_def split_def)
  apply (wpsimp wp: refill_update_invs commit_time_invs check_budget_invs
                    hoare_vcg_if_lift2 tcb_sched_action_bound_sc tcb_release_remove_bound_sc
                    update_sc_badge_invs' update_sc_sporadic_invs' get_object_wp commit_time_sc_active
                    tcb_sched_action_obj_at tcb_release_remove_obj_at
                    gts_wp hoare_vcg_const_imp_lift hoare_vcg_all_lift
         | wp (once) hoare_drop_imps)+
  apply (auto simp: invs_def valid_state_def valid_pspace_def idle_sc_no_ex_cap obj_at_def active_sc_def)
  done

text \<open>set_thread_state and schedcontext/schedcontrol invocations\<close>

crunch set_thread_state_act
  for st_tcb_at_tc[wp]: "\<lambda>s. st_tcb_at P (cur_thread s) s"
  and bound_yt_tcb_at_ct[wp]: "\<lambda>s. bound_yt_tcb_at P (cur_thread s) s"
  and sc_tcb_sc_at_ct[wp]: "\<lambda>s. sc_tcb_sc_at (P (cur_thread s)) t s"
  and release_queue[wp]: "\<lambda>s. P (release_queue s)"

lemma sts_valid_sched_control_inv[wp]:
  "\<lbrace>valid_sched_control_inv sci\<rbrace> set_thread_state t st \<lbrace>\<lambda>rv. valid_sched_control_inv sci\<rbrace>"
  by (cases sci; wpsimp wp: sts_obj_at_impossible)

lemma decode_sched_context_inv_inv:
  "\<lbrace>P\<rbrace> decode_sched_context_invocation label sc_ptr excaps args \<lbrace>\<lambda>rv. P\<rbrace>"
  apply (rule hoare_pre)
   apply (simp add: decode_sched_context_invocation_def
                    decode_sched_context_bind_def
                    decode_sched_context_unbind_object_def
                    decode_sched_context_yield_to_def
                    whenE_def
         split del: if_split
          | wp (once) hoare_drop_imp get_sk_obj_ref_inv get_sc_obj_ref_inv | wpcw)+
  done

lemma decode_sched_control_inv_inv:
  "\<lbrace>P\<rbrace> decode_sched_control_invocation_flags label args excaps \<lbrace>\<lambda>rv. P\<rbrace>"
  apply (rule hoare_pre)
   apply (simp add: decode_sched_control_invocation_flags_def whenE_def unlessE_def split del: if_split
          | wp (once) hoare_drop_imp get_sk_obj_ref_inv assertE_wp | wpcw)+
  done

lemma decode_sched_context_inv_wf:
  "\<lbrace>invs and sc_at sc_ptr and ex_nonz_cap_to sc_ptr and
     case_option \<top> in_user_frame args and
     (\<lambda>s. \<forall>x\<in>set excaps. s \<turnstile> x) and
     (\<lambda>s. \<forall>x\<in>set excaps. \<forall>r\<in>zobj_refs x. ex_nonz_cap_to r s)\<rbrace>
     decode_sched_context_invocation label sc_ptr excaps args
   \<lbrace>valid_sched_context_inv\<rbrace>, -"
  apply (wpsimp simp: decode_sched_context_invocation_def
                      decode_sched_context_bind_def
                      decode_sched_context_unbind_object_def
                      decode_sched_context_yield_to_def
                      whenE_def get_sk_obj_ref_def get_tcb_obj_ref_def get_sc_obj_ref_def
           split_del: if_split
                  wp: hoare_vcg_if_splitE get_simple_ko_wp thread_get_wp' get_sched_context_wp
                      gts_wp)
  apply (intro conjI; intro impI allI)
    apply (erule ballE[where x="hd excaps"])
     prefer 2
     apply (drule hd_in_set, simp)
    apply (rule conjI; intro impI allI)
     apply simp
     apply (erule ballE[where x="hd excaps"])
      prefer 2
      apply (drule hd_in_set, simp)
     apply (erule_tac x=x in ballE)
      apply (clarsimp simp add: obj_at_def sc_ntfn_sc_at_def)
     apply clarsimp
    apply (erule ballE[where x="hd excaps"])
     prefer 2
     apply (drule hd_in_set, simp)
    apply (erule_tac x=x in ballE)
     prefer 2
     apply (drule hd_in_set, simp)
    apply (clarsimp simp: obj_at_def pred_tcb_at_def sc_at_ppred_def)
   apply (frule invs_valid_global_refs, drule invs_valid_objs, clarsimp dest!: idle_no_ex_cap)
   apply (erule ballE[where x="hd excaps"])
    prefer 2
    apply (drule hd_in_set, simp)
   apply (rule conjI; intro impI allI)
    apply simp
    apply (erule ballE[where x="hd excaps"])
     prefer 2
     apply (drule hd_in_set, simp)
    apply (erule_tac x=x in ballE)
     apply (clarsimp simp: obj_at_def sc_ntfn_sc_at_def is_sc_obj_def)
    apply clarsimp
   apply (erule ballE[where x="hd excaps"])
    prefer 2
    apply (drule hd_in_set, simp)
   apply (erule_tac x=x in ballE)
    prefer 2
    apply (drule hd_in_set, simp)
   apply (clarsimp simp: obj_at_def pred_tcb_at_def sc_tcb_sc_at_def)
  apply (clarsimp simp: sc_tcb_sc_at_def obj_at_def is_sc_obj_def is_tcb pred_tcb_at_def
                        sc_yf_sc_at_def)
  done

lemma decode_sched_control_inv_wf:
  "\<lbrace>invs and
     (\<lambda>s. \<forall>x\<in>set excaps. s \<turnstile> x) and
     (\<lambda>s. \<forall>x\<in>set excaps. \<forall>r\<in>zobj_refs x. ex_nonz_cap_to r s)\<rbrace>
   decode_sched_control_invocation_flags label args excaps
   \<lbrace>valid_sched_control_inv\<rbrace>, -"
  apply (wpsimp simp: decode_sched_control_invocation_flags_def whenE_def unlessE_def assertE_def
           split_del: if_split)
  apply (erule ballE[where x="hd excaps"])
   prefer 2
   apply (drule hd_in_set, simp)
  apply (erule ballE[where x="hd excaps"])
   prefer 2
   apply (drule hd_in_set, simp)
  apply (clarsimp simp add: valid_cap_def obj_at_def is_sc_obj_def split: cap.split_asm)
  apply (rename_tac ko)
  apply (case_tac ko; simp)
  apply (clarsimp simp: valid_refills_number_def max_refills_cap_def MAX_PERIOD_def not_less
                  cong: conj_cong)
  apply (insert getCurrentTime_buffer_bound)
  apply (intro conjI impI; (fastforce intro: us_to_ticks_mono)?)
   apply (clarsimp simp: MIN_BUDGET_def MIN_BUDGET_US_def kernelWCET_ticks_def)
   apply (rule order_trans[OF MIN_BUDGET_helper])
   apply (fastforce intro: order_trans[OF mult_le_mono1] us_to_ticks_mono
                     simp: word_le_nat_alt)
  apply (fastforce intro: order_trans[OF mult_le_mono1] us_to_ticks_mono
                    simp: word_le_nat_alt)
  done

end
