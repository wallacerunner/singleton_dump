class Solution:
    def isMatch(self, s: str, p: str) -> bool:
        if s == p: return True

        parsed_p = []
        j = 0 # pattern position
        while j < len(p):
            if p[j] == '*':
                parsed_p[-1]['repeat'] = True
            elif p[j] == '.':
                parsed_p.append({'match': (('a', 'z'), ('A', 'Z')) })
            else:
                parsed_p.append({'match': ( (p[j], p[j]), ) })
            j += 1


        start_pos = 0
        i = 0
        rewind_targets = []
        while i < len(parsed_p):
            el = parsed_p[i]
            el['matched'] = False
            # print('current start position: ', start_pos)

            if 'repeat' in el:
                el['matched'] = True
                # print('match ', el['match'], ' from ', start_pos, ', repeating')
                rounds = 0
                for c in s[start_pos:]:
                    # print('char: ', c, end="")
                    if any([l <= c <= r for l, r in el['match'] ]):
                        # print(' - match')
                        rounds += 1
                        start_pos += 1
                    else:
                        # print('')
                        break
                # print('pattern matched: ', el['matched'])
                if rounds > 0:
                    rewind_targets.append((i, start_pos - 1, rounds))
            
            else:
                # print('match ', el['match'], ' from ', start_pos)
                for c in s[start_pos:]:
                    # print('char: ', c, end="")
                    if any([l <= c <= r for l, r in el['match'] ]):
                        # print(' - match')
                        el['matched'] = True
                        start_pos += 1
                    else:
                        # print('')
                        pass
                    break
                
                # print('pattern matched: ', el['matched'])
                if not el['matched'] and len(rewind_targets) > 0:
                    i, start_pos, rounds = rewind_targets.pop()
                    rounds -= 1
                    if rounds > 0:
                        rewind_targets.append((i, start_pos - 1, rounds))
            i += 1
        
        return all([e['matched'] for e in parsed_p]) and start_pos == len(s)
