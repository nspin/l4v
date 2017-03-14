(*
 * Copyright 2014, General Dynamics C4 Systems
 *
 * This software may be distributed and modified according to the terms of
 * the GNU General Public License version 2. Note that NO WARRANTY is provided.
 * See "LICENSE_GPLv2.txt" for details.
 *
 * @TAG(GD_GPL)
 *)

theory ArchStructures_H
imports
  "../../../lib/Lib"
  "../Types_H"
  Hardware_H
begin

context Arch begin global_naming X64_H

#INCLUDE_SETTINGS keep_constructor=asidpool
#INCLUDE_SETTINGS keep_constructor=arch_tcb

#INCLUDE_HASKELL SEL4/Object/Structures/X64.lhs CONTEXT X64_H decls_only
#INCLUDE_HASKELL SEL4/Object/Structures/X64.lhs CONTEXT X64_H instanceproofs
#INCLUDE_HASKELL SEL4/Object/Structures/X64.lhs CONTEXT X64_H bodies_only

datatype arch_kernel_object_type =
    PDET
  | PTET
  | PDPTET
  | PML4ET
  | ASIDPoolT

primrec
  archTypeOf :: "arch_kernel_object \<Rightarrow> arch_kernel_object_type"
where
  "archTypeOf (KOPDE e) = PDET"
| "archTypeOf (KOPTE e) = PTET"
| "archTypeOf (KOPDPTE e) = PDPTET"
| "archTypeOf (KOPML4E e) = PML4ET"
| "archTypeOf (KOASIDPool e) = ASIDPoolT"

end
end
