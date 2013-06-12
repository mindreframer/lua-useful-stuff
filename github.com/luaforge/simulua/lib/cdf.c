/*
 * Cumulative Distribution Function (CDF) library for Lua
 * Check license at the bottom of this file
 * $Id: cdf.c,v 1.1 2008-08-19 23:36:39 carvalho Exp $
*/

#include <math.h>
#include <lua.h>
#include <lauxlib.h>
#include "cdflib.h"

/* Utils */

static int cdf_expm1 (lua_State *L) {
  lua_Number x = luaL_checknumber(L, 1);
  lua_pushnumber(L, dexpm1(&x));
  return 1;
}

static int cdf_log1p (lua_State *L) {
  lua_Number x = luaL_checknumber(L, 1);
  lua_pushnumber(L, dln1px(&x));
  return 1;
}

static int cdf_lbeta (lua_State *L) {
  lua_Number a = luaL_checknumber(L, 1);
  lua_Number b = luaL_checknumber(L, 2);
  lua_pushnumber(L, dlnbet(&a, &b));
  return 1;
}

static int cdf_lgamma (lua_State *L) {
  lua_Number x = luaL_checknumber(L, 1);
  lua_pushnumber(L, dlngam(&x));
  return 1;
}

static int cdf_erf (lua_State *L) {
  lua_Number x = luaL_checknumber(L, 1);
  lua_pushnumber(L, erf1(&x));
  return 1;
}

static int cdf_erfc (lua_State *L) {
  lua_Number x = luaL_checknumber(L, 1);
  int ind = 0;
  lua_pushnumber(L, erfc1(&ind, &x));
  return 1;
}

/* Probability Dists */

/* Failsafe: execution shouldn't reach here (!), since most errors are checked
 * out by specific check_xxx routines; the only expected error is when status
 * == 10 */
static void check_status (int status, lua_Number bound) {
  if (status == 1)
    printf("Warning: result lower than search bound: %f", bound);
  if (status == 2)
    printf("Warning: result higher than search bound: %f", bound);
  if (status < 0)
    printf("Warning: out of range on parameter %d: %f", -status, bound);
  if (status == 10)
    printf("Warning: error in cumgam: %d", status);
}

static void check_beta (lua_State *L, int which, lua_Number x,
    lua_Number a, lua_Number b) {
  (void) which;
  luaL_argcheck(L, x>=0 && x<=1, 1, "out of range");
  luaL_argcheck(L, a>=0, 2, "non-negative value expected");
  luaL_argcheck(L, b>=0, 3, "non-negative value expected");
}

static int cdf_dbeta (lua_State *L) {
  /* stack should contain x, a and b */
  lua_Number x = luaL_checknumber(L, 1);
  lua_Number a = luaL_checknumber(L, 2);
  lua_Number b = luaL_checknumber(L, 3);
  check_beta(L, 1, x, a, b);
  lua_pushnumber(L, (x==0 || x==1) ? 0 :
      exp((a-1)*log(x)+(b-1)*log(1-x)-dlnbet(&a, &b)));
  return 1;
}

static int cdf_pbeta (lua_State *L) {
  /* stack should contain x, a and b */
  lua_Number x = luaL_checknumber(L, 1);
  lua_Number a = luaL_checknumber(L, 2);
  lua_Number b = luaL_checknumber(L, 3);
  lua_Number p, q, y, bound;
  int which = 1;
  int status;
  check_beta(L, 1, x, a, b);
  y = 1-x;
  cdfbet(&which, &p, &q, &x, &y, &a, &b, &status, &bound);
  check_status(status, bound);
  lua_pushnumber(L, p);
  return 1;
}

static int cdf_qbeta (lua_State *L) {
  /* stack should contain x, a and b */
  lua_Number p = luaL_checknumber(L, 1);
  lua_Number a = luaL_checknumber(L, 2);
  lua_Number b = luaL_checknumber(L, 3);
  lua_Number x;
  check_beta(L, 2, p, a, b);
  if (p==0 || p==1) x = p;
  else {
    lua_Number q, y, bound;
    int which = 2;
    int status;
    q = 1-p;
    cdfbet(&which, &p, &q, &x, &y, &a, &b, &status, &bound);
    check_status(status, bound);
  }
  lua_pushnumber(L, x);
  return 1;
}

static void check_binom (lua_State *L, int which, lua_Number x,
    lua_Number xn, lua_Number pr) {
  luaL_argcheck(L, ((which==1 && (x>=0 && x<=xn)) /* x */
      || (which==2 && (x>=0 && x<=1))), /* p */
      1, "out of range");
  luaL_argcheck(L, xn>=0, 2, "non-negative value expected");
  luaL_argcheck(L, pr>=0 && pr<=1, 3, "out of range");
}

static int cdf_dbinom (lua_State *L) {
  /* stack should contain s, xn, pr */
  lua_Number s = luaL_checknumber(L, 1);
  lua_Number xn = luaL_checknumber(L, 2);
  lua_Number pr = luaL_checknumber(L, 3);
  lua_Number d;
  check_binom(L, 1, s, xn, pr);
  xn -= s;
  d = s*log(pr)+xn*log(1-pr);
  xn++; s++; /* gamma correction */
  d = exp(d-dlnbet(&xn, &s)-log(xn+s-1));
  lua_pushnumber(L, d);
  return 1;
}

static int cdf_pbinom (lua_State *L) {
  /* stack should contain s, xn, pr */
  lua_Number s = luaL_checknumber(L, 1);
  lua_Number xn = luaL_checknumber(L, 2);
  lua_Number pr = luaL_checknumber(L, 3);
  lua_Number p, q, ompr, bound;
  int which = 1;
  int status;
  check_binom(L, 1, s, xn, pr);
  ompr = 1-pr;
  cdfbin(&which, &p, &q, &s, &xn, &pr, &ompr, &status, &bound);
  check_status(status, bound);
  lua_pushnumber(L, p);
  return 1;
}

static int cdf_qbinom (lua_State *L) {
  /* stack should contain p, xn, pr */
  lua_Number p = luaL_checknumber(L, 1);
  lua_Number xn = luaL_checknumber(L, 2);
  lua_Number pr = luaL_checknumber(L, 3);
  lua_Number s;
  int si;
  check_binom(L, 2, p, xn, pr);
  if (p==0 || p==1) s = p*xn;
  else {
    lua_Number q = 1-p;
    lua_Number ompr = 1-pr;
    lua_Number bound;
    int which = 2;
    int status;
    cdfbin(&which, &p, &q, &s, &xn, &pr, &ompr, &status, &bound);
    check_status(status, bound);
  }
  lua_number2int(si, s);
  lua_pushinteger(L, si);
  return 1;
}

static void check_chisq (lua_State *L, int which, lua_Number x,
    lua_Number df, lua_Number pnonc) {
  luaL_argcheck(L, ((which==1 && x>=0)  /* x */
      || (which==2 && (x>=0 && x<=1))), /* p */
      1, "out of range");
  if (pnonc==0)
    luaL_argcheck(L, df>0, 2, "positive value expected");
  else
    luaL_argcheck(L, df>=0, 2, "non-negative value expected");
}

static int cdf_dchisq (lua_State *L) {
  /* stack should contain x, df and opt. pnonc */
  lua_Number x = luaL_checknumber(L, 1);
  lua_Number df = luaL_checknumber(L, 2);
  lua_Number pnonc = 0;
  lua_Number d;
  check_chisq(L, 1, x, df, pnonc);
  /* compute central dchisq */
  d = df/2;
  d = exp((d-1)*log(x)-x/2-d*M_LN2-dlngam(&d));
  lua_pushnumber(L, d);
  return 1;
}

static int cdf_pchisq (lua_State *L) {
  /* stack should contain x, df and opt. pnonc */
  lua_Number x = luaL_checknumber(L, 1);
  lua_Number df = luaL_checknumber(L, 2);
  lua_Number pnonc = luaL_optnumber(L, 3, 0);
  lua_Number p, q, bound;
  int which = 1;
  int status;
  check_chisq(L, 1, x, df, pnonc);
  if (pnonc==0) /* central? */
    cdfchi(&which, &p, &q, &x, &df, &status, &bound);
  else /* non-central */
    cdfchn(&which, &p, &q, &x, &df, &pnonc, &status, &bound);
  check_status(status, bound);
  lua_pushnumber(L, p);
  return 1;
}

static int cdf_qchisq (lua_State *L) {
  /* stack should contain p, df and opt. pnonc */
  lua_Number p = luaL_checknumber(L, 1);
  lua_Number df = luaL_checknumber(L, 2);
  lua_Number pnonc = luaL_optnumber(L, 3, 0);
  lua_Number x;
  check_chisq(L, 2, p, df, pnonc);
  if (p==0 || p==1) x = (p==0) ? 0 : HUGE_VAL;
  else {
    lua_Number q = 1-p;
    lua_Number bound;
    int which = 2;
    int status;
    if (pnonc==0) /* central? */
      cdfchi(&which, &p, &q, &x, &df, &status, &bound);
    else /* non-central */
      cdfchn(&which, &p, &q, &x, &df, &pnonc, &status, &bound);
    check_status(status, bound);
  }
  lua_pushnumber(L, x);
  return 1;
}

static int cdf_dexp (lua_State *L) {
  /* stack should contain x and rate */
  lua_Number x = luaL_checknumber(L, 1);
  lua_Number l = luaL_checknumber(L, 2);
  lua_pushnumber(L, exp(-l*x)*l);
  return 1;
}

static int cdf_pexp (lua_State *L) {
  /* stack should contain x and rate */
  lua_Number x = luaL_checknumber(L, 1);
  lua_Number l = luaL_checknumber(L, 2);
  lua_pushnumber(L, 1-exp(-l*x));
  return 1;
}

static int cdf_qexp (lua_State *L) {
  /* stack should contain p and rate */
  lua_Number p = luaL_checknumber(L, 1);
  lua_Number l = luaL_checknumber(L, 2);
  luaL_argcheck(L, p>=0 && p<=1, 1, "out of range");
  lua_pushnumber(L, (p<1) ? -log(1-p)/l : HUGE_VAL);
  return 1;
}

static void check_f (lua_State *L, int which, lua_Number x,
    lua_Number dfn, lua_Number dfd) {
  luaL_argcheck(L, ((which==1 && x>=0)  /* x */
      || (which==2 && (x>=0 && x<=1))), /* p */
      1, "out of range");
  luaL_argcheck(L, dfn>=0, 2, "non-negative value expected");
  luaL_argcheck(L, dfd>=0, 3, "non-negative value expected");
}

static int cdf_df (lua_State *L) {
  /* stack should contain f, dfn, dfd */
  lua_Number f = luaL_checknumber(L, 1);
  lua_Number dfn = luaL_checknumber(L, 2);
  lua_Number dfd = luaL_checknumber(L, 3);
  lua_Number df1, df2, r, d;
  check_f(L, 1, f, dfn, dfd);
  df1 = dfn/2;
  df2 = dfd/2;
  r = dfn/dfd;
  d = df1*log(r)+(df1-1)*log(f);
  d -= (df1+df2)*log(1+r*f);
  d -= dlnbet(&df1, &df2);
  lua_pushnumber(L, exp(d));
  return 1;
}

static int cdf_pf (lua_State *L) {
  /* stack should contain f, dfn, dfd and opt. phonc */
  lua_Number f = luaL_checknumber(L, 1);
  lua_Number dfn = luaL_checknumber(L, 2);
  lua_Number dfd = luaL_checknumber(L, 3);
  lua_Number phonc = luaL_optnumber(L, 4, 0);
  lua_Number p, q, bound;
  int which = 1;
  int status;
  check_f(L, 1, f, dfn, dfd);
  if (phonc == 0) /* central? */
    cdff(&which, &p, &q, &f, &dfn, &dfd, &status, &bound);
  else /* non-central */
    cdffnc(&which, &p, &q, &f, &dfn, &dfd, &phonc, &status, &bound);
  check_status(status, bound);
  lua_pushnumber(L, p);
  return 1;
}

static int cdf_qf (lua_State *L) {
  /* stack should contain p, dfn, dfd and opt. phonc */
  lua_Number p = luaL_checknumber(L, 1);
  lua_Number dfn = luaL_checknumber(L, 2);
  lua_Number dfd = luaL_checknumber(L, 3);
  lua_Number phonc = luaL_optnumber(L, 4, 0);
  lua_Number f;
  check_f(L, 2, p, dfn, dfd);
  if (p==0 || p==1) f = (p==0) ? 0 : HUGE_VAL;
  else {
    lua_Number q = 1-p;
    lua_Number bound;
    int which = 2;
    int status;
    if (phonc == 0) /* central? */
      cdff(&which, &p, &q, &f, &dfn, &dfd, &status, &bound);
    else /* non-central */
      cdffnc(&which, &p, &q, &f, &dfn, &dfd, &phonc, &status, &bound);
    check_status(status, bound);
  }
  lua_pushnumber(L, f);
  return 1;
}

static void check_gamma (lua_State *L, int which, lua_Number x,
    lua_Number shape, lua_Number scale) {
  luaL_argcheck(L, ((which==1 && x>=0)  /* x */
      || (which==2 && (x>=0 && x<=1))), /* p */
      1, "out of range");
  luaL_argcheck(L, shape>=0, 2, "non-negative value expected");
  luaL_argcheck(L, scale>=0, 3, "non-negative value expected");
}

/* scale here is 1/rate */
static int cdf_dgamma (lua_State *L) {
  /* stack should contain x, shape and opt. scale */
  lua_Number x = luaL_checknumber(L, 1);
  lua_Number shape = luaL_checknumber(L, 2);
  lua_Number scale = luaL_optnumber(L, 3, 1);
  lua_Number d;
  check_gamma(L, 1, x, shape, scale);
  d = x * scale;
  d = exp(shape*log(d)-d-dlngam(&shape))/x;
  lua_pushnumber(L, d);
  return 1;
}

static int cdf_pgamma (lua_State *L) {
  /* stack should contain x, shape and opt. scale */
  lua_Number x = luaL_checknumber(L, 1);
  lua_Number shape = luaL_checknumber(L, 2);
  lua_Number scale = luaL_optnumber(L, 3, 1);
  lua_Number p, q, bound;
  int which = 1;
  int status;
  check_gamma(L, 1, x, shape, scale);
  cdfgam(&which, &p, &q, &x, &shape, &scale, &status, &bound);
  check_status(status, bound);
  lua_pushnumber(L, p);
  return 1;
}

static int cdf_qgamma (lua_State *L) {
  /* stack should contain p, shape and opt. scale */
  lua_Number p = luaL_checknumber(L, 1);
  lua_Number shape = luaL_checknumber(L, 2);
  lua_Number scale = luaL_optnumber(L, 3, 1);
  lua_Number x;
  check_gamma(L, 2, p, shape, scale);
  if (p==0 || p==1) x = (p==0) ? 0 : HUGE_VAL;
  else {
    lua_Number q = 1-p;
    lua_Number bound;
    int which = 2;
    int status;
    cdfgam(&which, &p, &q, &x, &shape, &scale, &status, &bound);
    check_status(status, bound);
  }
  lua_pushnumber(L, x);
  return 1;
}

static void check_nbinom (lua_State *L, int which, lua_Number x,
    lua_Number xn, lua_Number pr) {
  luaL_argcheck(L, ((which==1 && x>=0)  /* x */
      || (which==2 && (x>=0 && x<=1))), /* p */
      1, "out of range");
  luaL_argcheck(L, xn>=0, 2, "non-negative value expected");
  luaL_argcheck(L, pr>=0 && pr<=1, 3, "out of range");
}

static int cdf_dnbinom (lua_State *L) {
  /* stack should contain s, xn, pr */
  lua_Number s = luaL_checknumber(L, 1);
  lua_Number xn = luaL_checknumber(L, 2);
  lua_Number pr = luaL_checknumber(L, 3);
  lua_Number d;
  check_nbinom(L, 1, s, xn, pr);
  d = exp(xn*log(pr)+s*log(1-pr)-dlnbet(&s, &xn))/s;
  lua_pushnumber(L, d);
  return 1;
}

static int cdf_pnbinom (lua_State *L) {
  /* stack should contain s, xn, pr */
  lua_Number s = luaL_checknumber(L, 1);
  lua_Number xn = luaL_checknumber(L, 2);
  lua_Number pr = luaL_checknumber(L, 3);
  lua_Number p, q, ompr, bound;
  int which = 1;
  int status;
  check_nbinom(L, 1, s, xn, pr);
  ompr = 1 - pr;
  cdfnbn(&which, &p, &q, &s, &xn, &pr, &ompr, &status, &bound);
  check_status(status, bound);
  lua_pushnumber(L, p);
  return 1;
}

static int cdf_qnbinom (lua_State *L) {
  /* stack should contain p, xn, pr */
  lua_Number p = luaL_checknumber(L, 1);
  lua_Number xn = luaL_checknumber(L, 2);
  lua_Number pr = luaL_checknumber(L, 3);
  int si = 0;
  check_nbinom(L, 2, p, xn, pr);
  if (p==1) {
    lua_pushnumber(L, HUGE_VAL);
    return 1;
  }
  if (p>0) {
    lua_Number q = 1-p;
    lua_Number ompr = 1-pr;
    lua_Number s, bound;
    int which = 2;
    int status;
    cdfnbn(&which, &p, &q, &s, &xn, &pr, &ompr, &status, &bound);
    check_status(status, bound);
    lua_number2int(si, s);
  }
  lua_pushinteger(L, si);
  return 1;
}

static void check_norm (lua_State *L, int which, lua_Number x,
    lua_Number sd) {
  if (which==2) luaL_argcheck(L, x>=0 && x<=1,  /* p */
      1, "out of range");
  luaL_argcheck(L, sd>=0, 3, "non-negative value expected");
}

static int cdf_dnorm (lua_State *L) {
  /* stack should contain x, and opt. mean and sd */
  lua_Number x = luaL_checknumber(L, 1);
  lua_Number mean = luaL_optnumber(L, 2, 0);
  lua_Number sd = luaL_optnumber(L, 3, 1);
  lua_Number d;
  check_norm(L, 1, x, sd);
  d = (x-mean)/sd;
  d = exp(-d*d/2)/(sqrt(2*M_PI)*sd);
  lua_pushnumber(L, d);
  return 1;
}

static int cdf_pnorm (lua_State *L) {
  /* stack should contain x, and opt. mean and sd */
  lua_Number x = luaL_checknumber(L, 1);
  lua_Number mean = luaL_optnumber(L, 2, 0);
  lua_Number sd = luaL_optnumber(L, 3, 1);
  lua_Number p, q, bound;
  int which = 1;
  int status;
  check_norm(L, 1, x, sd);
  q = 1-p;
  cdfnor(&which, &p, &q, &x, &mean, &sd, &status, &bound);
  check_status(status, bound);
  lua_pushnumber(L, p);
  return 1;
}

static int cdf_qnorm (lua_State *L) {
  /* stack should contain p, and opt. mean and sd */
  lua_Number p = luaL_checknumber(L, 1);
  lua_Number mean = luaL_optnumber(L, 2, 0);
  lua_Number sd = luaL_optnumber(L, 3, 1);
  lua_Number x;
  check_norm(L, 2, p, sd);
  if (p==0 || p==1) x = (p==0) ? -HUGE_VAL : HUGE_VAL;
  else {
    lua_Number q = 1-p;
    lua_Number bound;
    int which = 2;
    int status;
    cdfnor(&which, &p, &q, &x, &mean, &sd, &status, &bound);
    check_status(status, bound);
  }
  lua_pushnumber(L, x);
  return 1;
}

static void check_pois (lua_State *L, int which, lua_Number x,
    lua_Number xlam) {
  luaL_argcheck(L, ((which==1 && x>=0)  /* x */
      || (which==2 && (x>=0 && x<=1))), /* p */
      1, "out of range");
  luaL_argcheck(L, xlam>=0, 2, "non-negative value expected");
}

static int cdf_dpois (lua_State *L) {
  /* stack should contain s and xlam */
  lua_Number s = luaL_checknumber(L, 1);
  lua_Number xlam = luaL_checknumber(L, 2);
  lua_Number d;
  check_pois(L, 1, s, xlam);
  d = s+1;
  d = exp(s*log(xlam)-xlam-dlngam(&d));
  lua_pushnumber(L, d);
  return 1;
}

static int cdf_ppois (lua_State *L) {
  /* stack should contain s and xlam */
  lua_Number s = luaL_checknumber(L, 1);
  lua_Number xlam = luaL_checknumber(L, 2);
  lua_Number p, q, bound;
  int which = 1;
  int status;
  check_pois(L, 1, s, xlam);
  q = 1-p;
  cdfpoi(&which, &p, &q, &s, &xlam, &status, &bound);
  check_status(status, bound);
  lua_pushnumber(L, p);
  return 1;
}

static int cdf_qpois (lua_State *L) {
  /* stack should contain p and xlam */
  lua_Number p = luaL_checknumber(L, 1);
  lua_Number xlam = luaL_checknumber(L, 2);
  int si = 0;
  check_pois(L, 2, p, xlam);
  if (p==1) {
    lua_pushnumber(L, HUGE_VAL);
    return 1;
  }
  if (p>0) {
    lua_Number q = 1-p;
    lua_Number s, bound;
    int which = 2;
    int status;
    cdfpoi(&which, &p, &q, &s, &xlam, &status, &bound);
    check_status(status, bound);
    lua_number2int(si, s);
  }
  lua_pushinteger(L, si);
  return 1;
}

static void check_t (lua_State *L, int which, lua_Number x,
    lua_Number df) {
  if (which==2) luaL_argcheck(L, x>=0 && x<=1,  /* p */
      1, "out of range");
  luaL_argcheck(L, df>=0, 3, "non-negative value expected");
}

static int cdf_dt (lua_State *L) {
  /* stack should contain x and df */
  lua_Number x = luaL_checknumber(L, 1);
  lua_Number df = luaL_checknumber(L, 2);
  lua_Number t = 0.5;
  lua_Number d;
  check_t(L, 1, x, df);
  d = df/2;
  d = -dlnbet(&d, &t)-(df+1)/2*log(1+x*x/df);
  d = exp(d)/sqrt(df);
  lua_pushnumber(L, d);
  return 1;
}

static int cdf_pt (lua_State *L) {
  /* stack should contain t and df */
  lua_Number t = luaL_checknumber(L, 1);
  lua_Number df = luaL_checknumber(L, 2);
  lua_Number p, q, bound;
  int which = 1;
  int status;
  check_t(L, 1, t, df);
  q = 1-p;
  cdft(&which, &p, &q, &t, &df, &status, &bound);
  check_status(status, bound);
  lua_pushnumber(L, p);
  return 1;
}

static int cdf_qt (lua_State *L) {
  /* stack should contain p and df */
  lua_Number p = luaL_checknumber(L, 1);
  lua_Number df = luaL_checknumber(L, 2);
  lua_Number t;
  check_t(L, 2, p, df);
  if (p==0 || p==1) t = (p==0) ? -HUGE_VAL : HUGE_VAL;
  else {
    lua_Number q = 1-p;
    lua_Number bound;
    int which = 2;
    int status;
    cdft(&which, &p, &q, &t, &df, &status, &bound);
    check_status(status, bound);
  }
  lua_pushnumber(L, t);
  return 1;
}


/* Interface */

static const luaL_reg cdf_lib[] = {
  /* utils */
  {"expm1", cdf_expm1},
  {"log1p", cdf_log1p},
  {"lbeta", cdf_lbeta},
  {"lgamma", cdf_lgamma},
  {"erf", cdf_erf},
  {"erfc", cdf_erfc},
  /* probability dists */
  {"dbeta", cdf_dbeta},
  {"pbeta", cdf_pbeta},
  {"qbeta", cdf_qbeta},
  {"dbinom", cdf_dbinom},
  {"pbinom", cdf_pbinom},
  {"qbinom", cdf_qbinom},
  {"dchisq", cdf_dchisq},
  {"pchisq", cdf_pchisq},
  {"qchisq", cdf_qchisq},
  {"dexp", cdf_dexp},
  {"pexp", cdf_pexp},
  {"qexp", cdf_qexp},
  {"df", cdf_df},
  {"pf", cdf_pf},
  {"qf", cdf_qf},
  {"dgamma", cdf_dgamma},
  {"pgamma", cdf_pgamma},
  {"qgamma", cdf_qgamma},
  {"dnbinom", cdf_dnbinom},
  {"pnbinom", cdf_pnbinom},
  {"qnbinom", cdf_qnbinom},
  {"dnorm", cdf_dnorm},
  {"pnorm", cdf_pnorm},
  {"qnorm", cdf_qnorm},
  {"dpois", cdf_dpois},
  {"ppois", cdf_ppois},
  {"qpois", cdf_qpois},
  {"dt", cdf_dt},
  {"pt", cdf_pt},
  {"qt", cdf_qt},
  {NULL, NULL}
};

int luaopen_cdf (lua_State *L) {
  lua_newtable(L);
  luaL_register(L, NULL, cdf_lib);
  return 1;
}


/* {=================================================================
*
* Copyright (c) 2008 Luis Carvalho
*
* Permission is hereby granted, free of charge, to any person
* obtaining a copy of this software and associated documentation files
* (the "Software"), to deal in the Software without restriction,
* including without limitation the rights to use, copy, modify,
* merge, publish, distribute, sublicense, and/or sell copies of the
* Software, and to permit persons to whom the Software is furnished
* to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
* NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
* BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
* ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
* CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* ==================================================================} */

