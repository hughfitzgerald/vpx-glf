// run-tests.js
// Builds glf.vbs from this checkout, assembles the test bed table, runs it in
// Visual Pinball and reports each scenario as passed or failed.
//
//   node tests/run-tests.js                 run every scenario in Visual Pinball
//   node tests/run-tests.js --headless      run them without Visual Pinball (see below)
//   node tests/run-tests.js --only a,b      run the named scenarios
//   node tests/run-tests.js --isolate       restart Visual Pinball for each scenario
//   node tests/run-tests.js --list          list scenario names
//   node tests/run-tests.js --keep-open     leave Visual Pinball running afterwards
//   node tests/run-tests.js --glf <file>    test an existing glf.vbs instead of building one
//   node tests/run-tests.js --timeout 600   seconds to wait for a run (default 300)
//   node tests/run-tests.js --assemble      build the table folder and stop, without running it
//
// Visual Pinball is found through the VPINBALL environment variable, or at the
// default macOS location.
//
// --headless runs the same script in glftest_host, a small program built on
// libwinevbs, the VBScript engine Visual Pinball standalone uses. Time is
// simulated, so a run takes a second or two. The first run fetches and builds
// libwinevbs, which needs git, cmake, bison and a C compiler. Set
// LIBWINEVBS_DIR to use a checkout you already have.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn, spawnSync } = require('child_process');

const testsDir = __dirname;
const repoRoot = path.join(testsDir, '..');
const scriptsDir = path.join(repoRoot, 'scripts');
const srcDir = path.join(testsDir, 'src');
const scenariosDir = path.join(srcDir, 'scenarios');
const workDir = path.join(testsDir, '.work');
const stageDir = path.join(workDir, 'glftest');
const resultsFile = path.join(workDir, 'results.txt');
const outputFile = path.join(workDir, 'vpx-output.log');

const headlessDir = path.join(testsDir, 'headless');
const hostBinary = path.join(workDir, process.platform === 'win32' ? 'glftest_host.exe' : 'glftest_host');
const LIBWINEVBS_REPO = 'https://github.com/vpinball/libwinevbs';
const LIBWINEVBS_COMMIT = 'aef82ffbd5fd248549007ed304fa670c187c28e9';

const VPINBALL = process.env.VPINBALL
    || '/Applications/VPinballX_BGFX.app/Contents/MacOS/VPinballX_BGFX';

// ---------- arguments ----------

function parseArgs(argv) {
    const args = { only: '', isolate: false, list: false, keepOpen: false, glf: '', timeout: 300, assemble: false, headless: false };
    for (let i = 0; i < argv.length; i++) {
        const arg = argv[i];
        if (arg === '--only') args.only = argv[++i] || '';
        else if (arg === '--isolate') args.isolate = true;
        else if (arg === '--list') args.list = true;
        else if (arg === '--keep-open') args.keepOpen = true;
        else if (arg === '--glf') args.glf = argv[++i] || '';
        else if (arg === '--timeout') args.timeout = Number(argv[++i]) || 300;
        else if (arg === '--assemble') args.assemble = true;
        else if (arg === '--headless') args.headless = true;
        else fail(`unknown option ${arg}`);
    }
    return args;
}

function fail(message) {
    console.error(`run-tests: ${message}`);
    process.exit(2);
}

// ---------- scenarios ----------

function scenarioFiles() {
    return fs.readdirSync(scenariosDir).filter((f) => f.endsWith('.vbs')).sort();
}

function scenarioNames() {
    const names = [];
    for (const file of scenarioFiles()) {
        const text = fs.readFileSync(path.join(scenariosDir, file), 'utf8');
        const pattern = /^\s*TB_(?:KnownIssue)?Scenario\s+"([^"]+)"/gim;
        let match;
        while ((match = pattern.exec(text)) !== null) names.push(match[1]);
    }
    return names;
}

// ---------- building ----------

function buildGlf(args) {
    if (args.glf) {
        const file = path.resolve(args.glf);
        if (!fs.existsSync(file)) fail(`no file at ${file}`);
        return { text: fs.readFileSync(file, 'utf8'), label: file };
    }
    if (!fs.existsSync(path.join(scriptsDir, 'node_modules'))) {
        fail(`run "npm install" in ${scriptsDir} first.`);
    }
    const build = spawnSync('npx', ['grunt', 'concat'], {
        cwd: scriptsDir,
        encoding: 'utf8',
        shell: process.platform === 'win32',
    });
    if (build.error || build.status !== 0) {
        console.error(build.stdout || '');
        console.error(build.stderr || '');
        fail('grunt concat failed.');
    }
    return { text: fs.readFileSync(path.join(scriptsDir, 'vpx-glf.vbs'), 'utf8'), label: gitLabel() };
}

function gitLabel() {
    const git = (...a) => spawnSync('git', a, { cwd: repoRoot, encoding: 'utf8' });
    const branch = git('rev-parse', '--abbrev-ref', 'HEAD');
    const sha = git('rev-parse', '--short', 'HEAD');
    if (branch.status !== 0 || sha.status !== 0) return 'this checkout';
    const dirty = git('status', '--porcelain', '--untracked-files=no').stdout.trim() ? '-dirty' : '';
    return `${branch.stdout.trim()} @ ${sha.stdout.trim()}${dirty}`;
}

function vbsString(text) {
    return `"${String(text).replace(/"/g, '""')}"`;
}

// Writes the table folder Visual Pinball will play
function assemble(glfText, only, quitWhenDone) {
    fs.rmSync(stageDir, { recursive: true, force: true });
    fs.mkdirSync(workDir, { recursive: true });
    fs.cpSync(path.join(testsDir, 'table'), stageDir, { recursive: true });
    // Folders a table pack normally has; this table needs nothing in them
    for (const dir of ['images', 'sounds', 'materials', 'meshes']) {
        fs.mkdirSync(path.join(stageDir, dir), { recursive: true });
    }

    const runConfig = [
        "' Generated by tests/run-tests.js for this run",
        `Const TB_RESULTS_FILE = ${vbsString(resultsFile)}`,
        `Const TB_ONLY = ${vbsString(only)}`,
        `Const TB_QUIT_WHEN_DONE = ${quitWhenDone ? 'True' : 'False'}`,
        '',
    ].join('\n');

    const read = (file) => fs.readFileSync(file, 'utf8');
    const parts = [
        read(path.join(srcDir, '00_globals.vbs')),
        runConfig,
        read(path.join(srcDir, '10_virtual_table.vbs')),
        read(path.join(srcDir, '20_config.vbs')),
        read(path.join(srcDir, '30_runner.vbs')),
        ...scenarioFiles().map((f) => read(path.join(scenariosDir, f))),
        read(path.join(srcDir, '90_table.vbs')),
        glfText,
    ];
    fs.writeFileSync(path.join(stageDir, 'script.vbs'), parts.join('\n'));
}

// ---------- running ----------

// Places the table script might have written results, if it could not use the path it was given
function resultCandidates() {
    return [
        resultsFile,
        path.join(workDir, 'glftest_results.txt'),
        path.join(stageDir, 'glftest_results.txt'),
        path.join(process.cwd(), 'glftest_results.txt'),
        path.join(os.homedir(), 'glftest_results.txt'),
    ];
}

function readResults() {
    for (const file of resultCandidates()) {
        if (fs.existsSync(file)) {
            return fs.readFileSync(file, 'utf8').split(/\r?\n/).filter((line) => line.startsWith('TB|'));
        }
    }
    return [];
}

function clearResults() {
    for (const file of resultCandidates()) fs.rmSync(file, { force: true });
}

function showLine(line) {
    const [, kind, scenario, a, b, c, d] = line.split('|');
    if (kind === 'START') console.log(`\n${scenario}`);
    else if (kind === 'PASS') console.log(`    ok    ${a}`);
    else if (kind === 'FAIL') console.log(`    FAIL  ${a}: ${b || ''}`);
    else if (kind === 'NOTE') console.log(`    note  ${a}`);
    else if (kind === 'END') {
        const word = a === 'passed' ? 'PASSED' : a === 'known' ? 'KNOWN ISSUE' : 'FAILED';
        console.log(`  ${word} (${b} ok, ${c} failed, ${(Number(d) / 1000).toFixed(1)}s)`);
    }
}

// Runs Visual Pinball once and resolves with the result lines it produced
function runOnce(timeoutSeconds, keepOpen) {
    return new Promise((resolve) => {
        clearResults();
        const output = fs.createWriteStream(outputFile, { flags: 'a' });
        const child = spawn(VPINBALL, ['-Play', stageDir], { cwd: workDir });
        child.stdout.on('data', (data) => output.write(data));
        child.stderr.on('data', (data) => output.write(data));

        let shown = 0;
        let finished = false;
        let exited = null;
        const started = Date.now();

        const finish = (reason) => {
            if (finished) return;
            finished = true;
            clearInterval(timer);
            const lines = readResults();
            for (; shown < lines.length; shown++) showLine(lines[shown]);
            if (!keepOpen && exited === null) child.kill();
            output.end();
            resolve({ lines, reason });
        };

        child.on('error', (error) => {
            exited = -1;
            console.error(`run-tests: could not start ${VPINBALL}: ${error.message}`);
            console.error('run-tests: set the VPINBALL environment variable to your Visual Pinball executable.');
            finish('could not start Visual Pinball');
        });
        child.on('exit', (code) => {
            exited = code;
            // Give the last lines a moment to reach the disk
            setTimeout(() => finish(readResults().some((l) => l.startsWith('TB|DONE')) ? 'done' : `Visual Pinball exited early (code ${code})`), 300);
        });

        const timer = setInterval(() => {
            const lines = readResults();
            for (; shown < lines.length; shown++) showLine(lines[shown]);
            if (lines.some((l) => l.startsWith('TB|DONE'))) {
                setTimeout(() => finish('done'), 1000);
            } else if ((Date.now() - started) / 1000 > timeoutSeconds) {
                finish(`timed out after ${timeoutSeconds}s`);
            }
        }, 500);
    });
}

// ---------- headless ----------

function runTool(command, commandArgs, cwd, what) {
    const result = spawnSync(command, commandArgs, { cwd, encoding: 'utf8' });
    if (result.error || result.status !== 0) {
        console.error(result.stdout || '');
        console.error(result.stderr || '');
        fail(`${what} failed. The headless runner needs git, cmake, bison and a C compiler.`);
    }
}

// Fetches and builds libwinevbs if needed, then builds glftest_host
function ensureHost() {
    fs.mkdirSync(workDir, { recursive: true });
    const libDir = process.env.LIBWINEVBS_DIR ? path.resolve(process.env.LIBWINEVBS_DIR) : path.join(workDir, 'libwinevbs');
    if (!fs.existsSync(path.join(libDir, 'CMakeLists.txt'))) {
        console.log('Fetching libwinevbs (first run only)...');
        runTool('git', ['clone', '--quiet', LIBWINEVBS_REPO, libDir], workDir, 'Fetching libwinevbs');
        runTool('git', ['checkout', '--quiet', LIBWINEVBS_COMMIT], libDir, 'Selecting the libwinevbs version');
    }
    const library = path.join(libDir, 'build', 'libwinevbs.a');
    if (!fs.existsSync(library)) {
        console.log('Building libwinevbs (first run only)...');
        const platform = process.platform === 'darwin' ? 'macos' : 'linux';
        const arch = process.arch === 'arm64' ? (platform === 'macos' ? 'arm64' : 'aarch64') : 'x64';
        runTool('cmake', ['-DCMAKE_BUILD_TYPE=Release', `-DPLATFORM=${platform}`, `-DARCH=${arch}`, '-DBUILD_SHARED=OFF', '-B', 'build'], libDir, 'Configuring libwinevbs');
        runTool('cmake', ['--build', 'build', '--target', 'winevbs_static', '-j', '4'], libDir, 'Building libwinevbs');
    }
    const source = path.join(headlessDir, 'host.c');
    const stale = !fs.existsSync(hostBinary) || fs.statSync(hostBinary).mtimeMs < fs.statSync(source).mtimeMs;
    if (stale) {
        runTool(process.env.CC || 'cc', [
            '-O2', '-D__LIBWINEVBS__', '-D__WINESRC__', '-DWINE_UNICODE_NATIVE',
            `-I${path.join(libDir, 'include')}`, `-I${path.join(libDir, 'wine', 'include')}`,
            `-I${path.join(libDir, 'atl', 'include')}`, `-I${path.join(libDir, 'atlmfc', 'include')}`,
            source, library, '-lm', '-o', hostBinary,
        ], workDir, 'Building glftest_host');
    }
}

// Runs the assembled script in glftest_host and resolves with the result lines
function runHeadless(simulatedSeconds) {
    return new Promise((resolve) => {
        const child = spawn(hostBinary, [path.join(headlessDir, 'prelude.vbs'), path.join(stageDir, 'script.vbs'), String(simulatedSeconds), '10'], { cwd: workDir });
        const lines = [];
        let pending = '';
        const take = (data) => {
            fs.appendFileSync(outputFile, data);
            pending += data.toString();
            const parts = pending.split(/\r?\n/);
            pending = parts.pop();
            for (const line of parts) {
                if (line.startsWith('TB|')) {
                    lines.push(line);
                    showLine(line);
                }
            }
        };
        child.stdout.on('data', take);
        child.stderr.on('data', take);
        child.on('error', (error) => resolve({ lines, reason: `could not start glftest_host: ${error.message}` }));
        child.on('exit', () => resolve({ lines, reason: lines.some((l) => l.startsWith('TB|DONE')) ? 'done' : 'the script stopped before finishing' }));
    });
}

function scriptErrors() {
    if (!fs.existsSync(outputFile)) return [];
    return fs.readFileSync(outputFile, 'utf8').split(/\r?\n/)
        .filter((line, index, all) => /script error|runtime error|compile error|OnScriptError/i.test(line)
            || (index > 0 && /^\s+> /.test(line) && /script error/i.test(all[index - 1])));
}

// ---------- main ----------

async function main() {
    const args = parseArgs(process.argv.slice(2));
    const names = scenarioNames();

    if (args.list) {
        names.forEach((name) => console.log(name));
        return;
    }

    const wanted = args.only ? args.only.split(',').map((s) => s.trim()).filter(Boolean) : names;
    for (const name of wanted) {
        if (!names.includes(name)) fail(`no scenario called ${name}. Use --list to see them.`);
    }

    const glf = buildGlf(args);
    fs.mkdirSync(workDir, { recursive: true });
    fs.rmSync(outputFile, { force: true });

    if (args.assemble) {
        assemble(glf.text, args.only, false);
        console.log(`Table folder written to ${stageDir}`);
        return;
    }
    if (args.headless) {
        ensureHost();
    } else if (!fs.existsSync(VPINBALL)) {
        fail(`Visual Pinball not found at ${VPINBALL}. Set the VPINBALL environment variable, or use --headless.`);
    }

    console.log(`GLF test bed: testing ${glf.label}${args.headless ? ' (headless)' : ''}`);

    const batches = args.isolate ? wanted.map((name) => [name]) : [wanted];
    const all = [];
    const problems = [];
    for (const batch of batches) {
        assemble(glf.text, args.only || args.isolate ? batch.join(',') : '', !args.keepOpen);
        const { lines, reason } = args.headless
            ? await runHeadless(args.timeout * 4)
            : await runOnce(args.timeout, args.keepOpen);
        all.push(...lines);
        if (reason !== 'done') problems.push(`${batch.join(', ')}: ${reason}`);
    }

    const ends = all.filter((l) => l.startsWith('TB|END|')).map((l) => l.split('|'));
    const passed = ends.filter((e) => e[3] === 'passed').map((e) => e[2]);
    const known = ends.filter((e) => e[3] === 'known').map((e) => e[2]);
    const failed = ends.filter((e) => e[3] === 'failed').map((e) => e[2]);
    const notRun = wanted.filter((name) => !ends.some((e) => e[2] === name));

    console.log('\n----------------------------------------');
    console.log(`GLF under test: ${glf.label}`);
    console.log(`Passed: ${passed.length}   Failed: ${failed.length}   Known issues: ${known.length}   Not run: ${notRun.length}`);
    if (failed.length) console.log(`Failed: ${failed.join(', ')}`);
    if (known.length) console.log(`Known issues: ${known.join(', ')}`);
    if (notRun.length) console.log(`Not run: ${notRun.join(', ')}`);
    for (const problem of problems) console.log(`Problem: ${problem}`);

    const errors = scriptErrors();
    if (errors.length) {
        console.log('\nScript errors reported by Visual Pinball:');
        errors.slice(0, 20).forEach((line) => console.log(`  ${line}`));
    }
    if (problems.length || notRun.length) {
        console.log(`\nThe full output is in ${outputFile}`);
    }

    process.exit(failed.length || notRun.length || problems.length ? 1 : 0);
}

main();
