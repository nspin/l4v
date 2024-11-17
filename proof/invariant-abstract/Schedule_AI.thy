(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * SPDX-License-Identifier: GPL-2.0-only
 *)

theory Schedule_AI
imports SchedContext_AI
begin

arch_requalify_facts
  no_irq
  no_irq_storeWord

abbreviation
  "activatable \<equiv> \<lambda>st. runnable st \<or> idle st"

locale Schedule_AI =
    fixes state_ext :: "('a::state_ext) itself"
    assumes dmo_mapM_storeWord_0_invs[wp]:
      "\<And>S. valid invs (do_machine_op (mapM (\<lambda>p. storeWord p 0) S)) (\<lambda>_. (invs :: 'a state \<Rightarrow> bool))"
    assumes arch_stt_invs [wp]:
      "\<And>t'. \<lbrace>invs\<rbrace> arch_switch_to_thread t' \<lbrace>\<lambda>_. (invs :: 'a state \<Rightarrow> bool)\<rbrace>"
    assumes arch_stt_tcb [wp]:
      "\<And>t'. \<lbrace>tcb_at t'\<rbrace> arch_switch_to_thread t' \<lbrace>\<lambda>_. (tcb_at t' :: 'a state \<Rightarrow> bool)\<rbrace>"
    assumes arch_stt_sc_at[wp]:
      "\<And>t' sc_ptr. arch_switch_to_thread t' \<lbrace>(sc_at sc_ptr :: 'a state \<Rightarrow> bool)\<rbrace>"
    assumes arch_stt_runnable:
      "\<And>t. \<lbrace>st_tcb_at Q t\<rbrace> arch_switch_to_thread t
            \<lbrace>\<lambda>r . (st_tcb_at Q t :: 'a state \<Rightarrow> bool)\<rbrace>"
    assumes arch_stt_scheduler_action:
      "\<And>t'. \<lbrace>\<lambda>s::'a state. P (scheduler_action s)\<rbrace>
             arch_switch_to_thread t' \<lbrace>\<lambda>_ s. P (scheduler_action s)\<rbrace>"
    assumes arch_stit_invs [wp]:
      "\<And>t'. \<lbrace>invs\<rbrace> arch_switch_to_idle_thread \<lbrace>\<lambda>_. (invs :: 'a state \<Rightarrow> bool)\<rbrace>"
    assumes arch_stit_tcb [wp]:
      "\<And>t'. \<lbrace>tcb_at t\<rbrace> arch_switch_to_idle_thread \<lbrace>\<lambda>_. (tcb_at t :: 'a state \<Rightarrow> bool)\<rbrace>"
    assumes arch_stit_sc_at [wp]:
      "\<And>sc_ptr. arch_switch_to_idle_thread \<lbrace>(sc_at sc_ptr :: 'a state \<Rightarrow> bool)\<rbrace>"
    assumes arch_stit_scheduler_action:
      "\<And>t'. \<lbrace>\<lambda>s::'a state. P (scheduler_action s)\<rbrace>
             arch_switch_to_idle_thread \<lbrace>\<lambda>_ s. P (scheduler_action s)\<rbrace>"
    assumes stit_activatable:
      "\<lbrace>invs\<rbrace> switch_to_idle_thread \<lbrace>\<lambda>rv . (ct_in_state activatable :: 'a state \<Rightarrow> bool)\<rbrace>"

crunch schedule_switch_thread_fastfail
  for inv[wp]: P

lemma findM_inv'':
  assumes p: "suffix xs xs'"
  assumes x: "\<And>x xs. suffix (x # xs) xs' \<Longrightarrow> \<lbrace>P (x # xs)\<rbrace> m x \<lbrace>\<lambda>rv s. (rv \<longrightarrow> Q s) \<and> (\<not> rv \<longrightarrow> P xs s)\<rbrace>"
  assumes y: "\<And>s. P [] s \<Longrightarrow> Q s"
  shows      "\<lbrace>P xs\<rbrace> findM m xs \<lbrace>\<lambda>rv. Q\<rbrace>"
  using p
  apply (induct xs)
   apply simp
   apply wp
   apply (erule y)
  apply (frule suffix_ConsD)
  apply simp
  apply wp
   apply (erule x)
  apply simp
  done

lemmas findM_inv' = findM_inv''[OF suffix_order.refl]

lemma findM_inv:
  assumes x: "\<And>x. \<lbrace>P\<rbrace> m x \<lbrace>\<lambda>rv. P\<rbrace>"
  shows      "\<lbrace>P\<rbrace> findM m xs \<lbrace>\<lambda>rv. P\<rbrace>"
  by (rule findM_inv', simp_all add: x)

(*
lemma allActiveTCBs_gets:
  "allActiveTCBs = gets (\<lambda>state. {x. getActiveTCB x state \<noteq> None})"
  by (simp add: allActiveTCBs_def gets_def)
*)

lemma postfix_tails:
  "\<lbrakk> suffix (xs # ys) (tails zs) \<rbrakk>
     \<Longrightarrow> suffix xs zs \<and> (xs # ys) = tails xs"
  apply (induct zs arbitrary: xs ys)
   apply (clarsimp elim!: suffixE)
   apply (case_tac zs, simp_all)[1]
  apply (clarsimp elim!: suffixE)
  apply (case_tac zsa, simp_all)
   apply clarsimp
  apply clarsimp
  apply (erule meta_allE, erule meta_allE, drule meta_mp,
         rule suffix_appendI[OF suffix_order.refl])
  apply clarsimp
  apply (erule suffix_ConsI)
  done


lemma valid_irq_states_cur_thread_update[simp]:
  "valid_irq_states (cur_thread_update f s) = valid_irq_states s"
  by(simp add: valid_irq_states_def)

lemma storeWord_valid_irq_states:
  "\<lbrace>\<lambda>m. valid_irq_states (s\<lparr>machine_state := m\<rparr>)\<rbrace> storeWord x y
   \<lbrace>\<lambda>a b. valid_irq_states (s\<lparr>machine_state := b\<rparr>)\<rbrace>"
  apply (simp add: valid_irq_states_def | wp no_irq | simp add: no_irq_storeWord)+
  done

lemma dmo_storeWord_valid_irq_states[wp]:
  "\<lbrace>valid_irq_states\<rbrace> do_machine_op (storeWord x y) \<lbrace>\<lambda>_. valid_irq_states\<rbrace>"
  apply (simp add: do_machine_op_def |  wp | wpc)+
  apply clarsimp
  apply(erule use_valid[OF _ storeWord_valid_irq_states])
  by simp

lemma dmo_kheap_arch_state[wp]:
  "\<lbrace>\<lambda>s. P (kheap s) (arch_state s)\<rbrace>
   do_machine_op a
   \<lbrace>\<lambda>_ s. P (kheap s) (arch_state s)\<rbrace>"
  by (clarsimp simp: do_machine_op_def simpler_gets_def select_f_def
          simpler_modify_def return_def bind_def valid_def)

lemmas do_machine_op_tcb[wp] =
  do_machine_op_obj_at[where P=id and Q=is_tcb, simplified]

lemma (in Schedule_AI) stt_tcb [wp]:
  "\<lbrace>tcb_at t\<rbrace> switch_to_thread t \<lbrace>\<lambda>_. (tcb_at t :: 'a state \<Rightarrow> bool)\<rbrace>"
  apply (simp add: switch_to_thread_def)
  apply (wp hoare_drop_imps | simp)+
   done

lemma (in Schedule_AI) stt_activatable:
  "\<lbrace>st_tcb_at activatable t\<rbrace> switch_to_thread t \<lbrace>\<lambda>rv . (ct_in_state activatable :: 'a state \<Rightarrow> bool) \<rbrace>"
  apply (simp add: switch_to_thread_def)
  apply (wp | simp add: ct_in_state_def)+
     apply (rule hoare_post_imp [OF _ arch_stt_runnable], assumption)
    apply (rule assert_inv)
   apply (wpsimp wp: hoare_drop_imp)+
  done

(* FIXME move *)
lemma pred_tcb_weaken_strongerE:
  "\<lbrakk> pred_tcb_at proj P t s; \<And>tcb . P (proj tcb) \<Longrightarrow> P' (proj' tcb) \<rbrakk> \<Longrightarrow> pred_tcb_at proj' P' t s"
  by (auto simp: pred_tcb_at_def elim: obj_at_weakenE)

lemma OR_choice_weak_wp:
  "\<lbrace>P\<rbrace> f \<sqinter> g \<lbrace>Q\<rbrace> \<Longrightarrow> \<lbrace>P\<rbrace> OR_choice b f g \<lbrace>Q\<rbrace>"
  apply (fastforce simp add: OR_choice_def alternative_def valid_def bind_def
                    select_f_def gets_def return_def get_def
          split: option.splits if_split_asm)
  done
(*
locale Schedule_AI_U = Schedule_AI "TYPE(unit)"

lemma (in Schedule_AI_U) schedule_invs[wp]:
  "\<lbrace>invs\<rbrace> (Schedule_A.schedule :: (unit,unit) s_monad) \<lbrace>\<lambda>rv. invs\<rbrace>"
  apply (simp add: Schedule_A.schedule_def allActiveTCBs_def)
  apply (wp OR_choice_weak_wp dmo_invs thread_get_inv sc_and_timer_invs
            do_machine_op_tcb select_ext_weak_wp when_def
          | clarsimp simp: getActiveTCB_def get_tcb_def)+
  done

lemma (in Schedule_AI_U) schedule_ct_activateable[wp]:
  "\<lbrace>invs\<rbrace> (Schedule_A.schedule :: (unit,unit) s_monad) \<lbrace>\<lambda>rv. ct_in_state activatable \<rbrace>"
  proof -
  have P: "\<And>t s. ct_in_state activatable (cur_thread_update (\<lambda>_. t) s) = st_tcb_at activatable t s"
    by (fastforce simp: ct_in_state_def pred_tcb_at_def intro: obj_at_pspaceI)
  have Q: "\<And>s. invs s \<longrightarrow> idle_thread s = cur_thread s \<longrightarrow> ct_in_state activatable s"
    apply (clarsimp simp: ct_in_state_def dest!: invs_valid_idle)
    apply (clarsimp simp: valid_idle_def pred_tcb_def2)
    done
  show ?thesis
    apply (simp add: Schedule_A.schedule_def allActiveTCBs_def)
    apply (wp sc_and_timer_activatable select_ext_weak_wp stt_activatable stit_activatable
           | simp add: P Q)+
    apply (clarsimp simp: getActiveTCB_def ct_in_state_def)
    apply (rule conjI)
     apply clarsimp
     apply (case_tac "get_tcb (cur_thread s) s", simp_all add: ct_in_state_def is_schedulable_opt_def)
     apply (drule get_tcb_SomeD)
     apply (clarsimp simp: pred_tcb_at_def obj_at_def split: if_split_asm option.split_asm)
    apply (case_tac "get_tcb x s", simp_all add: is_schedulable_opt_def)
    apply (drule get_tcb_SomeD)
    apply (clarsimp simp: pred_tcb_at_def obj_at_def split: if_split_asm option.split_asm)
  done
qed
*)

end
