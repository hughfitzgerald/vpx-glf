/*
 * glftest_host: runs the GLF test bed without Visual Pinball.
 *
 * It embeds libwinevbs, the VBScript engine Visual Pinball standalone uses,
 * and supplies the few things the table script expects from the player:
 *
 *   gametime        a simulated clock in milliseconds
 *   Table1          Option(), Width, Height, Name
 *   TB_HostPrint    writes a line to stdout
 *   TB_HostQuit     ends the run
 *
 * Everything else Visual Pinball would provide is defined in prelude.vbs.
 * The host loads the prelude and the assembled script.vbs, calls Table1_Init,
 * then calls TB_HostTick once per simulated frame until the script quits.
 *
 * Usage: glftest_host <prelude.vbs> <script.vbs> [max simulated seconds] [frame ms]
 */

#define COBJMACROS

#include "libwinevbs.h"
#include <oleauto.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

static const GUID g_iid_null = {0};

/* The GUIDs are defined inside the static library; this only declares the one used here. */
DEFINE_GUID(CLSID_VBScript, 0xb54f3741, 0x5b07, 0x11cf, 0xa4, 0xb0, 0x0, 0xaa, 0x0, 0x4a, 0x55, 0xe8);

#define ASP_QueryInterface IActiveScriptParse64_QueryInterface
#define ASP_Release IActiveScriptParse64_Release
#define ASP_InitNew IActiveScriptParse64_InitNew
#define ASP_ParseScriptText IActiveScriptParse64_ParseScriptText

static long g_now_ms = 0;
static int g_quit = 0;
static int g_error_count = 0;
static const WCHAR *g_current_source = NULL;   /* text being parsed or run, for error messages */
static const char *g_current_name = "";

/* ---------- small helpers ---------- */

static void print_wide(FILE *out, const WCHAR *text)
{
   for (; *text; text++) {
      unsigned long c = (unsigned long)*text;
      if (c < 0x80) fputc((int)c, out);
      else if (c < 0x800) { fputc(0xC0 | (c >> 6), out); fputc(0x80 | (c & 0x3F), out); }
      else if (c < 0x10000) { fputc(0xE0 | (c >> 12), out); fputc(0x80 | ((c >> 6) & 0x3F), out); fputc(0x80 | (c & 0x3F), out); }
      else { fputc(0xF0 | (c >> 18), out); fputc(0x80 | ((c >> 12) & 0x3F), out); fputc(0x80 | ((c >> 6) & 0x3F), out); fputc(0x80 | (c & 0x3F), out); }
   }
}

/* Reads a file as UTF-8. A byte that is not valid UTF-8 is taken as Latin-1. */
static WCHAR *read_script(const char *path)
{
   FILE *file = fopen(path, "rb");
   if (!file) {
      fprintf(stderr, "glftest_host: cannot open %s\n", path);
      return NULL;
   }
   fseek(file, 0, SEEK_END);
   long size = ftell(file);
   fseek(file, 0, SEEK_SET);
   unsigned char *bytes = malloc((size_t)size + 1);
   if (fread(bytes, 1, (size_t)size, file) != (size_t)size) {
      fprintf(stderr, "glftest_host: cannot read %s\n", path);
      fclose(file);
      free(bytes);
      return NULL;
   }
   fclose(file);
   bytes[size] = 0;

   WCHAR *text = malloc(((size_t)size + 1) * sizeof(WCHAR));
   long in = 0, out = 0;
   if (size >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) in = 3;
   while (in < size) {
      unsigned char b = bytes[in];
      if (b < 0x80) { text[out++] = b; in++; }
      else if ((b & 0xE0) == 0xC0 && in + 1 < size && (bytes[in + 1] & 0xC0) == 0x80) {
         text[out++] = (WCHAR)(((b & 0x1F) << 6) | (bytes[in + 1] & 0x3F));
         in += 2;
      }
      else if ((b & 0xF0) == 0xE0 && in + 2 < size && (bytes[in + 1] & 0xC0) == 0x80 && (bytes[in + 2] & 0xC0) == 0x80) {
         text[out++] = (WCHAR)(((b & 0x0F) << 12) | ((bytes[in + 1] & 0x3F) << 6) | (bytes[in + 2] & 0x3F));
         in += 3;
      }
      else { text[out++] = b; in++; }
   }
   text[out] = 0;
   free(bytes);
   return text;
}

/* Prints one line of the current source, counted from zero */
static void print_source_line(const WCHAR *source, unsigned long line)
{
   if (!source) return;
   const WCHAR *p = source;
   for (unsigned long i = 0; i < line && *p; p++) {
      if (*p == L'\n') i++;
   }
   if (!*p) return;
   printf("    > ");
   for (int n = 0; *p && *p != L'\n' && *p != L'\r' && n < 200; p++, n++) {
      WCHAR one[2] = { *p, 0 };
      print_wide(stdout, one);
   }
   printf("\n");
}

static void log_callback(libwinevbs_log_level_t level, const char *format, va_list args)
{
   if (level != LIBWINEVBS_LOG_ERROR && level != LIBWINEVBS_LOG_WARN) return;
   printf("[engine %s] ", level == LIBWINEVBS_LOG_ERROR ? "error" : "warning");
   vprintf(format, args);
   printf("\n");
}

/* ---------- shared IDispatch plumbing ---------- */

static HRESULT WINAPI Obj_QueryInterface(IDispatch *iface, REFIID riid, void **ppv)
{
   if (IsEqualGUID(riid, &IID_IUnknown) || IsEqualGUID(riid, &IID_IDispatch)) {
      *ppv = iface;
      return S_OK;
   }
   *ppv = NULL;
   return E_NOINTERFACE;
}
static ULONG WINAPI Obj_AddRef(IDispatch *iface) { return 2; }
static ULONG WINAPI Obj_Release(IDispatch *iface) { return 1; }
static HRESULT WINAPI Obj_GetTypeInfoCount(IDispatch *iface, UINT *count) { *count = 0; return S_OK; }
static HRESULT WINAPI Obj_GetTypeInfo(IDispatch *iface, UINT i, LCID lcid, ITypeInfo **info) { return E_NOTIMPL; }

static int same_name(const WCHAR *a, const WCHAR *b)
{
   for (; *a && *b; a++, b++) {
      WCHAR x = *a, y = *b;
      if (x >= L'A' && x <= L'Z') x += 32;
      if (y >= L'A' && y <= L'Z') y += 32;
      if (x != y) return 0;
   }
   return *a == *b;
}

static HRESULT lookup_names(const WCHAR *const *known, LPOLESTR *names, UINT count, DISPID *ids)
{
   for (UINT i = 0; i < count; i++) {
      ids[i] = DISPID_UNKNOWN;
      for (int k = 0; known[k]; k++) {
         if (same_name(names[i], known[k])) ids[i] = k + 1;
      }
      if (ids[i] == DISPID_UNKNOWN) return DISP_E_UNKNOWNNAME;
   }
   return S_OK;
}

/* ---------- Host: members become script globals ---------- */

static const WCHAR *const g_host_names[] = { L"gametime", L"TB_HostPrint", L"TB_HostQuit", NULL };

static HRESULT WINAPI Host_GetIDsOfNames(IDispatch *iface, REFIID riid, LPOLESTR *names, UINT count, LCID lcid, DISPID *ids)
{
   return lookup_names(g_host_names, names, count, ids);
}

static HRESULT WINAPI Host_Invoke(IDispatch *iface, DISPID id, REFIID riid, LCID lcid,
   WORD flags, DISPPARAMS *params, VARIANT *result, EXCEPINFO *ei, UINT *err)
{
   switch (id) {
   case 1: /* gametime */
      if (result) {
         V_VT(result) = VT_I4;
         V_I4(result) = g_now_ms;
      }
      return S_OK;
   case 2: /* TB_HostPrint text */
      if (params->cArgs >= 1) {
         VARIANT text;
         VariantInit(&text);
         if (SUCCEEDED(VariantChangeType(&text, &params->rgvarg[params->cArgs - 1], 0, VT_BSTR)) && V_BSTR(&text)) {
            print_wide(stdout, V_BSTR(&text));
            printf("\n");
         }
         VariantClear(&text);
      }
      return S_OK;
   case 3: /* TB_HostQuit */
      g_quit = 1;
      return S_OK;
   }
   return DISP_E_MEMBERNOTFOUND;
}

static IDispatchVtbl g_host_vtbl = {
   Obj_QueryInterface, Obj_AddRef, Obj_Release, Obj_GetTypeInfoCount, Obj_GetTypeInfo,
   Host_GetIDsOfNames, Host_Invoke
};
static IDispatch g_host_obj = { &g_host_vtbl };

/* ---------- Table1 ---------- */

static const WCHAR *const g_table_names[] = { L"Option", L"Width", L"Height", L"Name", NULL };

static HRESULT WINAPI Table_GetIDsOfNames(IDispatch *iface, REFIID riid, LPOLESTR *names, UINT count, LCID lcid, DISPID *ids)
{
   return lookup_names(g_table_names, names, count, ids);
}

static HRESULT WINAPI Table_Invoke(IDispatch *iface, DISPID id, REFIID riid, LCID lcid,
   WORD flags, DISPPARAMS *params, VARIANT *result, EXCEPINFO *ei, UINT *err)
{
   switch (id) {
   case 1: /* Option(name, min, max, step, default, unit [, values]) returns the default */
      if (params->cArgs < 5) return DISP_E_BADPARAMCOUNT;
      if (result) return VariantCopy(result, &params->rgvarg[params->cArgs - 5]);
      return S_OK;
   case 2: /* Width */
      if (result) { V_VT(result) = VT_R4; V_R4(result) = 952.0f; }
      return S_OK;
   case 3: /* Height */
      if (result) { V_VT(result) = VT_R4; V_R4(result) = 2162.0f; }
      return S_OK;
   case 4: /* Name */
      if (result) { V_VT(result) = VT_BSTR; V_BSTR(result) = SysAllocString(L"Table1"); }
      return S_OK;
   }
   return DISP_E_MEMBERNOTFOUND;
}

static IDispatchVtbl g_table_vtbl = {
   Obj_QueryInterface, Obj_AddRef, Obj_Release, Obj_GetTypeInfoCount, Obj_GetTypeInfo,
   Table_GetIDsOfNames, Table_Invoke
};
static IDispatch g_table_obj = { &g_table_vtbl };

/* ---------- script site ---------- */

typedef struct { IActiveScriptSiteVtbl *lpVtbl; } ScriptSite;

static HRESULT WINAPI Site_QueryInterface(IActiveScriptSite *iface, REFIID riid, void **ppv)
{
   if (IsEqualGUID(riid, &IID_IUnknown) || IsEqualGUID(riid, &IID_IActiveScriptSite)) {
      *ppv = iface;
      return S_OK;
   }
   *ppv = NULL;
   return E_NOINTERFACE;
}
static ULONG WINAPI Site_AddRef(IActiveScriptSite *iface) { return 2; }
static ULONG WINAPI Site_Release(IActiveScriptSite *iface) { return 1; }
static HRESULT WINAPI Site_GetLCID(IActiveScriptSite *iface, LCID *lcid) { *lcid = 0; return S_OK; }

static HRESULT WINAPI Site_GetItemInfo(IActiveScriptSite *iface, LPCOLESTR name, DWORD mask, IUnknown **unk, ITypeInfo **info)
{
   if (info) *info = NULL;
   if (unk && same_name(name, L"Host")) { *unk = (IUnknown *)&g_host_obj; return S_OK; }
   if (unk && same_name(name, L"Table1")) { *unk = (IUnknown *)&g_table_obj; return S_OK; }
   return TYPE_E_ELEMENTNOTFOUND;
}

static HRESULT WINAPI Site_GetDocVersionString(IActiveScriptSite *iface, BSTR *version) { *version = SysAllocString(L"1.0"); return S_OK; }
static HRESULT WINAPI Site_OnScriptTerminate(IActiveScriptSite *iface, const VARIANT *result, const EXCEPINFO *ei) { return S_OK; }
static HRESULT WINAPI Site_OnStateChange(IActiveScriptSite *iface, SCRIPTSTATE state) { return S_OK; }

static HRESULT WINAPI Site_OnScriptError(IActiveScriptSite *iface, IActiveScriptError *error)
{
   EXCEPINFO ei = {0};
   DWORD context = 0;
   ULONG line = 0;
   LONG column = 0;
   IActiveScriptError_GetExceptionInfo(error, &ei);
   IActiveScriptError_GetSourcePosition(error, &context, &line, &column);
   g_error_count++;
   printf("SCRIPT ERROR at %ldms, %s line %lu col %ld: ", g_now_ms, g_current_name, (unsigned long)line + 1, (long)column);
   if (ei.bstrDescription) print_wide(stdout, ei.bstrDescription);
   else printf("(no description, code 0x%08X)", (unsigned)ei.scode);
   printf("\n");
   print_source_line(g_current_source, line);
   fflush(stdout);
   SysFreeString(ei.bstrDescription);
   SysFreeString(ei.bstrSource);
   SysFreeString(ei.bstrHelpFile);
   return S_OK;
}

static HRESULT WINAPI Site_OnEnterScript(IActiveScriptSite *iface) { return S_OK; }
static HRESULT WINAPI Site_OnLeaveScript(IActiveScriptSite *iface) { return S_OK; }

static IActiveScriptSiteVtbl g_site_vtbl = {
   Site_QueryInterface, Site_AddRef, Site_Release, Site_GetLCID, Site_GetItemInfo,
   Site_GetDocVersionString, Site_OnScriptTerminate, Site_OnStateChange, Site_OnScriptError,
   Site_OnEnterScript, Site_OnLeaveScript
};
static ScriptSite g_site = { &g_site_vtbl };

/* ---------- running ---------- */

static int parse(IActiveScriptParse *parser, const WCHAR *text, const char *name)
{
   EXCEPINFO ei = {0};
   g_current_source = text;
   g_current_name = name;
   HRESULT hr = ASP_ParseScriptText(parser, text, NULL, NULL, NULL, 0, 0, 0, NULL, &ei);
   if (FAILED(hr)) {
      printf("glftest_host: %s did not load (0x%08X)\n", name, (unsigned)hr);
      return 0;
   }
   return 1;
}

/* Calls a Sub in the script by name. Returns 0 if the script has no such Sub. */
static int call_sub(IDispatch *script, const WCHAR *name)
{
   DISPID id;
   LPOLESTR names[1] = { (LPOLESTR)name };
   DISPPARAMS no_args = { NULL, NULL, 0, 0 };
   EXCEPINFO ei = {0};
   if (FAILED(IDispatch_GetIDsOfNames(script, &g_iid_null, names, 1, 0, &id))) return 0;
   IDispatch_Invoke(script, id, &g_iid_null, 0, DISPATCH_METHOD, &no_args, NULL, &ei, NULL);
   SysFreeString(ei.bstrDescription);
   SysFreeString(ei.bstrSource);
   SysFreeString(ei.bstrHelpFile);
   return 1;
}

int main(int argc, char **argv)
{
   if (argc < 3) {
      fprintf(stderr, "usage: glftest_host <prelude.vbs> <script.vbs> [max simulated seconds] [frame ms]\n");
      return 2;
   }
   long max_ms = (argc > 3 ? atol(argv[3]) : 900) * 1000;
   long frame_ms = argc > 4 ? atol(argv[4]) : 10;
   if (frame_ms < 1) frame_ms = 1;

   WCHAR *prelude = read_script(argv[1]);
   WCHAR *script = read_script(argv[2]);
   if (!prelude || !script) return 2;

   libwinevbs_callbacks_t callbacks = { .log = log_callback };
   libwinevbs_init(&callbacks);

   IActiveScriptParse *parser = NULL;
   if (FAILED(CoCreateInstance(&CLSID_VBScript, NULL, CLSCTX_INPROC_SERVER, &IID_IActiveScriptParse, (void **)&parser))) {
      fprintf(stderr, "glftest_host: could not create the VBScript engine\n");
      return 2;
   }
   IActiveScript *engine = NULL;
   ASP_QueryInterface(parser, &IID_IActiveScript, (void **)&engine);
   IActiveScript_SetScriptSite(engine, (IActiveScriptSite *)&g_site);
   ASP_InitNew(parser);
   IActiveScript_AddNamedItem(engine, L"Host", SCRIPTITEM_ISVISIBLE | SCRIPTITEM_GLOBALMEMBERS);
   IActiveScript_AddNamedItem(engine, L"Table1", SCRIPTITEM_ISVISIBLE);
   IActiveScript_SetScriptState(engine, SCRIPTSTATE_STARTED);

   int loaded = parse(parser, prelude, "prelude.vbs") && parse(parser, script, "script.vbs");
   if (!loaded || g_error_count > 0) {
      printf("glftest_host: the script did not load cleanly; stopping\n");
      return 1;
   }

   IDispatch *script_dispatch = NULL;
   IActiveScript_GetScriptDispatch(engine, NULL, &script_dispatch);
   if (!script_dispatch) {
      fprintf(stderr, "glftest_host: could not reach the script's procedures\n");
      return 2;
   }

   if (!call_sub(script_dispatch, L"Table1_Init")) {
      printf("glftest_host: the script has no Table1_Init\n");
      return 1;
   }
   while (!g_quit && g_now_ms < max_ms) {
      g_now_ms += frame_ms;
      call_sub(script_dispatch, L"TB_HostTick");
   }
   fflush(stdout);
   if (!g_quit) printf("glftest_host: stopped after %ld simulated seconds without the script finishing\n", max_ms / 1000);

   IDispatch_Release(script_dispatch);
   IActiveScript_Close(engine);
   IActiveScript_Release(engine);
   ASP_Release(parser);
   libwinevbs_shutdown();
   return g_quit ? 0 : 1;
}
