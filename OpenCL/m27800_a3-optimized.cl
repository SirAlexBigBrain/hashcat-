/**
 * Author......: See docs/credits.txt
 * License.....: MIT
 */

#define NEW_SIMD_CODE

#define XSTR(x) #x
#define STR(x) XSTR(x)

#ifdef KERNEL_STATIC
#include STR(INCLUDE_PATH/inc_vendor.h)
#include STR(INCLUDE_PATH/inc_types.h)
#include STR(INCLUDE_PATH/inc_platform.cl)
#include STR(INCLUDE_PATH/inc_common.cl)
#include STR(INCLUDE_PATH/inc_simd.cl)
#endif

DECLSPEC u32x Murmur32_Scramble(u32x k)
{
  k = (k * 0x16A88000) | ((k * 0xCC9E2D51) >> 17);
  return (k * 0x1B873593);
}

DECLSPEC u32x MurmurHash3(const u32 seed, const u32x w0, const u32* data, const u32 size) {
  u32x checksum = seed;

  if (size >= 4)
  {
    checksum ^= Murmur32_Scramble(w0);
    checksum = (checksum >> 19) | (checksum << 13); //rotateRight(checksum, 19)
    checksum = (checksum * 5) + 0xE6546B64;

    const u32 nBlocks = (size / 4);
    if (size >= 4) //Hash blocks, sizes of 4
    {
      for (u32 i = 1; i < nBlocks; i++)
      {
        checksum ^= Murmur32_Scramble(data[i]);
        checksum = (checksum >> 19) | (checksum << 13); //rotateRight(checksum, 19)
        checksum = (checksum * 5) + 0xE6546B64;
      }
    }

    if (size % 4)
    {
      const u8* remainder = (u8*)(data + nBlocks);
      u32x val = 0;

      switch(size & 3) //Hash remaining bytes as size isn't always aligned by 4
      {
        case 3:
          val ^= (remainder[2] << 16);
        case 2:
          val ^= (remainder[1] << 8);
        case 1:
          val ^= remainder[0];
          checksum ^= Murmur32_Scramble(val);
        default:
          break;
      };
    }
  }

  else
  {
    if (size % 4)
    {
      const u8* remainder = (u8*)(&w0);
      u32x val = 0;

      switch(size & 3)
      {
        case 3:
          val ^= (remainder[2] << 16);
        case 2:
          val ^= (remainder[1] << 8);
        case 1:
          val ^= remainder[0];
          checksum ^= Murmur32_Scramble(val);
        default:
          break;
      };
    }
  }

  checksum ^= size;
  checksum ^= checksum >> 16;
  checksum *= 0x85EBCA6B;
  checksum ^= checksum >> 13;
  checksum *= 0xC2B2AE35;
  return checksum ^ (checksum >> 16);
}

DECLSPEC void m27800m (const u32 *w, const u32 pw_len, KERN_ATTR_VECTOR ())
{
  /**
   * modifier
   */

  const u64 gid = get_global_id (0);
  const u64 lid = get_local_id (0);

  /**
   * seed
   */

  const u32 seed = salt_bufs[SALT_POS_HOST].salt_buf[0];

  /**
   * loop
   */

  u32 w0l = w[0];

  for (u32 il_pos = 0; il_pos < IL_CNT; il_pos += VECT_SIZE)
  {
    const u32x w0r = words_buf_r[il_pos / VECT_SIZE];

    const u32x w0 = w0l | w0r;

    const u32x hash = MurmurHash3 (seed, w0, w, pw_len);

    const u32x r0 = hash;
    const u32x r1 = 0;
    const u32x r2 = 0;
    const u32x r3 = 0;

    COMPARE_M_SIMD (r0, r1, r2, r3);
  }
}

DECLSPEC void m27800s (const u32 *w, const u32 pw_len, KERN_ATTR_VECTOR ())
{
  /**
   * modifier
   */

  const u64 gid = get_global_id (0);
  const u64 lid = get_local_id (0);

  /**
   * digest
   */

  const u32 search[4] =
  {
    digests_buf[DIGESTS_OFFSET_HOST].digest_buf[DGST_R0],
    0,
    0,
    0
  };

  /**
   * seed
   */

  const u32 seed = salt_bufs[SALT_POS_HOST].salt_buf[0];

  /**
   * loop
   */

  u32 w0l = w[0];

  for (u32 il_pos = 0; il_pos < IL_CNT; il_pos += VECT_SIZE)
  {
    const u32x w0r = words_buf_r[il_pos / VECT_SIZE];

    const u32x w0 = w0l | w0r;

    const u32x hash = MurmurHash3 (seed, w0, w, pw_len);

    const u32x r0 = hash;
    const u32x r1 = 0;
    const u32x r2 = 0;
    const u32x r3 = 0;

    COMPARE_S_SIMD (r0, r1, r2, r3);
  }
}

KERNEL_FQ void m27800_m04 (KERN_ATTR_VECTOR ())
{
  /**
   * base
   */

  const u64 gid = get_global_id (0);

  if (gid >= GID_CNT) return;

  u32 w[16];

  w[ 0] = pws[gid].i[ 0];
  w[ 1] = pws[gid].i[ 1];
  w[ 2] = pws[gid].i[ 2];
  w[ 3] = pws[gid].i[ 3];
  w[ 4] = 0;
  w[ 5] = 0;
  w[ 6] = 0;
  w[ 7] = 0;
  w[ 8] = 0;
  w[ 9] = 0;
  w[10] = 0;
  w[11] = 0;
  w[12] = 0;
  w[13] = 0;
  w[14] = pws[gid].i[14];
  w[15] = 0;

  const u32 pw_len = pws[gid].pw_len & 63;

  /**
   * main
   */

  m27800m (w, pw_len, pws, rules_buf, combs_buf, words_buf_r, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_extra0_buf, d_extra1_buf, d_extra2_buf, d_extra3_buf, kernel_param);
}

KERNEL_FQ void m27800_m08 (KERN_ATTR_VECTOR ())
{
  /**
   * base
   */

  const u64 gid = get_global_id (0);

  if (gid >= GID_CNT) return;

  u32 w[16];

  w[ 0] = pws[gid].i[ 0];
  w[ 1] = pws[gid].i[ 1];
  w[ 2] = pws[gid].i[ 2];
  w[ 3] = pws[gid].i[ 3];
  w[ 4] = pws[gid].i[ 4];
  w[ 5] = pws[gid].i[ 5];
  w[ 6] = pws[gid].i[ 6];
  w[ 7] = pws[gid].i[ 7];
  w[ 8] = 0;
  w[ 9] = 0;
  w[10] = 0;
  w[11] = 0;
  w[12] = 0;
  w[13] = 0;
  w[14] = pws[gid].i[14];
  w[15] = 0;

  const u32 pw_len = pws[gid].pw_len & 63;

  /**
   * main
   */

  m27800m (w, pw_len, pws, rules_buf, combs_buf, words_buf_r, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_extra0_buf, d_extra1_buf, d_extra2_buf, d_extra3_buf, kernel_param);
}

KERNEL_FQ void m27800_m16 (KERN_ATTR_VECTOR ())
{
  /**
   * base
   */

  const u64 gid = get_global_id (0);

  if (gid >= GID_CNT) return;

  u32 w[16];

  w[ 0] = pws[gid].i[ 0];
  w[ 1] = pws[gid].i[ 1];
  w[ 2] = pws[gid].i[ 2];
  w[ 3] = pws[gid].i[ 3];
  w[ 4] = pws[gid].i[ 4];
  w[ 5] = pws[gid].i[ 5];
  w[ 6] = pws[gid].i[ 6];
  w[ 7] = pws[gid].i[ 7];
  w[ 8] = pws[gid].i[ 8];
  w[ 9] = pws[gid].i[ 9];
  w[10] = pws[gid].i[10];
  w[11] = pws[gid].i[11];
  w[12] = pws[gid].i[12];
  w[13] = pws[gid].i[13];
  w[14] = pws[gid].i[14];
  w[15] = pws[gid].i[15];

  const u32 pw_len = pws[gid].pw_len & 63;

  /**
   * main
   */

  m27800m (w, pw_len, pws, rules_buf, combs_buf, words_buf_r, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_extra0_buf, d_extra1_buf, d_extra2_buf, d_extra3_buf, kernel_param);
}

KERNEL_FQ void m27800_s04 (KERN_ATTR_VECTOR ())
{
  /**
   * base
   */

  const u64 gid = get_global_id (0);

  if (gid >= GID_CNT) return;

  u32 w[16];

  w[ 0] = pws[gid].i[ 0];
  w[ 1] = pws[gid].i[ 1];
  w[ 2] = pws[gid].i[ 2];
  w[ 3] = pws[gid].i[ 3];
  w[ 4] = 0;
  w[ 5] = 0;
  w[ 6] = 0;
  w[ 7] = 0;
  w[ 8] = 0;
  w[ 9] = 0;
  w[10] = 0;
  w[11] = 0;
  w[12] = 0;
  w[13] = 0;
  w[14] = pws[gid].i[14];
  w[15] = 0;

  const u32 pw_len = pws[gid].pw_len & 63;

  /**
   * main
   */

  m27800s (w, pw_len, pws, rules_buf, combs_buf, words_buf_r, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_extra0_buf, d_extra1_buf, d_extra2_buf, d_extra3_buf, kernel_param);
}

KERNEL_FQ void m27800_s08 (KERN_ATTR_VECTOR ())
{
  /**
   * base
   */

  const u64 gid = get_global_id (0);

  if (gid >= GID_CNT) return;

  u32 w[16];

  w[ 0] = pws[gid].i[ 0];
  w[ 1] = pws[gid].i[ 1];
  w[ 2] = pws[gid].i[ 2];
  w[ 3] = pws[gid].i[ 3];
  w[ 4] = pws[gid].i[ 4];
  w[ 5] = pws[gid].i[ 5];
  w[ 6] = pws[gid].i[ 6];
  w[ 7] = pws[gid].i[ 7];
  w[ 8] = 0;
  w[ 9] = 0;
  w[10] = 0;
  w[11] = 0;
  w[12] = 0;
  w[13] = 0;
  w[14] = pws[gid].i[14];
  w[15] = 0;

  const u32 pw_len = pws[gid].pw_len & 63;

  /**
   * main
   */

  m27800s (w, pw_len, pws, rules_buf, combs_buf, words_buf_r, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_extra0_buf, d_extra1_buf, d_extra2_buf, d_extra3_buf, kernel_param);
}

KERNEL_FQ void m27800_s16 (KERN_ATTR_VECTOR ())
{
  /**
   * base
   */

  const u64 gid = get_global_id (0);

  if (gid >= GID_CNT) return;

  u32 w[16];

  w[ 0] = pws[gid].i[ 0];
  w[ 1] = pws[gid].i[ 1];
  w[ 2] = pws[gid].i[ 2];
  w[ 3] = pws[gid].i[ 3];
  w[ 4] = pws[gid].i[ 4];
  w[ 5] = pws[gid].i[ 5];
  w[ 6] = pws[gid].i[ 6];
  w[ 7] = pws[gid].i[ 7];
  w[ 8] = pws[gid].i[ 8];
  w[ 9] = pws[gid].i[ 9];
  w[10] = pws[gid].i[10];
  w[11] = pws[gid].i[11];
  w[12] = pws[gid].i[12];
  w[13] = pws[gid].i[13];
  w[14] = pws[gid].i[14];
  w[15] = pws[gid].i[15];

  const u32 pw_len = pws[gid].pw_len & 63;

  /**
   * main
   */

  m27800s (w, pw_len, pws, rules_buf, combs_buf, words_buf_r, tmps, hooks, bitmaps_buf_s1_a, bitmaps_buf_s1_b, bitmaps_buf_s1_c, bitmaps_buf_s1_d, bitmaps_buf_s2_a, bitmaps_buf_s2_b, bitmaps_buf_s2_c, bitmaps_buf_s2_d, plains_buf, digests_buf, hashes_shown, salt_bufs, esalt_bufs, d_return_buf, d_extra0_buf, d_extra1_buf, d_extra2_buf, d_extra3_buf, kernel_param);
}
